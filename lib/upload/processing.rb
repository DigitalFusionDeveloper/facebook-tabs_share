###################################################################################
# processing support
###################################################################################

# support for named processing strategies on uploads and batch processing
# uploads
#
#
#   Upload.processing 'resize' do |upload|
#     if upload.image? and upload.grid_fs?
#       blob = upload.data
#
#       {
#         :small => '100x',
#         :teeny => '42x',
#
#       }.each do |name, dimensions|
#
#         upload.resize!(name, dimensions)
#
#       end
#     end
#     p "resize-ing #{ upload.inspect }..."
#     true
#   end
#
#   Upload.processing 's3' do |upload|
#     p "s3-ing #{ upload.inspect }..."
#     true
#   end
#
#   upload = Upload.upload!( 'app/assets/images/logo.png' )
#   upload.processing = %w[ resize s3 ]
#   puts
#   p upload.processing_steps
#
#
#   Upload.process_all do |processing_step|
#     upload = processing_step.upload
#     name = processing_step.name
#     puts "Upload.processing: upload=#{ upload.id }, name=#{ name.inspect }"
#   end
#
#   p upload.reload
#   p upload.variants.map(&:url)
#

class Upload
  class ProcessingStep
    include App::Document::Embedded

    field(:name, :type => String)
    field(:type, :type => String)
    field(:args, :type => Array, :default => proc{ Array.new })
    field(:success, :type => Boolean, :default => proc{ false })
    field(:completed_at, :type => Time)
    field(:scheduled_at, :type => Time, :default => proc{ Time.now.utc})
    field(:error, :type => type_for(:map))

    validates_uniqueness_of(:name, :scope => :type)

    def completed?
      !!completed_at
    end

    def exception
      unless error.blank?
        e = error['class'].constantize.new(error.message)
        e.set_backtrace(Array(error['backtrace']))
        e
      end
    end

    def run(&block)
      processing_step = self
      return nil if processing_step.completed?

      processing = processing_for(type)

      block.call(processing_step) if block

      begin
        name = "#{ self.name }"
        args = self.args.map{|arg| arg.dup}

        success = 
          if processing
            processing.call(upload, name, *args)
          else
            upload.send(type, *args)
          end

        processing_step.success = !!success
        processing_step.completed_at = Time.now.utc
        processing_step.error = nil
      rescue Object => e
        error = {
          'message'   => e.message.to_s,
          'class'     => e.class.name.to_s,
          'backtrace' => Array(e.backtrace).map{|line| line.to_s}
        }
        processing_step.success = false
        processing_step.completed_at = nil
        processing_step.error = error
      end

      upload.save!
    end

    def run!(&block)
      update_attributes!(:completed_at => nil)
      run(&block)
    end

    def processing_for(type)
      processing = Upload.processing[type]
    end

    embedded_in(:upload, :class_name => "::Upload")
  end

  embeds_many(:processing_steps, :class_name => '::Upload::ProcessingStep', :cascade_callbacks => true)

  index({'processing_steps' => 1})
  index({'processing_steps.completed_at' => 1})
  index({'processing_steps.scheduled_at' => 1})

  def Upload.processing(*args, &block)
    @processing ||= Map.new

    return @processing if args.empty? and block.nil?

    type = args.shift.to_s

    if block
      @processing[type] = block
    end

    @processing[type]
  end

  def Upload.auto_orient(upload)
    images = {}

    upload.variants.each do |variant|
      name = variant.name
      image = MiniMagick::Image.read(variant.data)
      image.auto_orient
      images[name] = image
    end

    images.each do |name, image|
      sio = SIO.new(image.to_blob, :pathname => upload.basename)
      variant = upload.add_variant!(name, sio)
    end

    upload
  end

  def auto_orient
    Upload.auto_orient(upload = self)
  end

  def Upload.resize(upload, name, *args)
    raise ArgumentError if name.to_s == 'original'

    options = args.extract_options!.to_options!
    dimensions = options.delete(:dimensions) || args.join('x')
    enlarge = options.delete(:enlarge)

    image = MiniMagick::Image.read(upload.original.data)

    upload_width = upload.magick[:width]

    width, height = width_and_height_for(dimensions)

    variant = nil

    can_resize =
      if enlarge == false
        width && width < upload_width
      else
        true
      end

    if can_resize
      image.resize(*dimensions)
      sio = SIO.new(image.to_blob, :pathname => upload.basename)
      variant = upload.add_variant(name, sio)
    else
      variant = false
    end

    variant
  end

  Upload.processing[:resize] = Upload.method(:resize).to_proc

  def Upload.create_sizes!(upload, options = {})
    options.to_options!

    sizes = options[:sizes] || Upload.default_sizes

    processing = Hash.new

    sizes.each do |name, dimensions|
      args = [:resize, dimensions, {:enlarge => false}]
      processing[name] = args
    end

    upload.set_processing(processing)

    if options[:background]
      job = Job.submit(Upload, :process, upload.id)
    else
      Upload.process(upload.id)
      upload.reload
    end

    sizes
  end

  def Upload.create_sizes(*args, &block)
    begin
      Upload.create_sizes!(*args, &block) or true
    rescue Object => e
      false
    end
  end

  def Upload.default_sizes
    config.sizes
  end

  def resize(name, *args, &block)
    Upload.resize(upload=self, name, *args, &block)
  end

  def Upload.to_process(options = {})
    options.to_options!

    at = Coerce.time(options[:at] || Time.now).utc

    Upload.where(
      'processing_steps' => {'$ne' => nil},

      'processing_steps.completed_at' => nil,

      '$or' => [
        {'processing_steps.scheduled_at' => nil},
        {'processing_steps.scheduled_at' => {'$lte' => at}}
      ]
    )
  end

  def Upload.process_all(query = to_process, &block)
    results = []

    query.each do |upload|
      upload.process_all do |processing_step|
        if block
          block.call(upload, processing_step)
        else
          results.push([upload, processing_step])
        end
      end
    end

    block ? nil : results
  end

  def Upload.process_all!(&block)
    Upload.process_all(Upload.all, &block)
  end

  def Upload.process(id)
    upload = Upload.find(id)
    upload.process_all
  end

  def process_all(&block)
    upload = self

    upload.processing_steps.each do |processing_step|
      processing_step.run(&block)
    end

    reload
  end

  def process_all!(&block)
    update_attributes('processing_steps.completed_at' => nil)
    process_all(&block)
  end

  def processing
    processing_steps.map do |processing_step|
      {
        processing_step.name => {
          processing_step.type => processing_step.args
        }
      }
    end
  end

  def set_processing(*args, &block)
    processing_steps.clear
    add_processing(*args, &block)
  end

  def add_processing(hash = {})
    hash.each do |name, value|
      attributes =
        case value
          when Hash
            value.to_options.update(:name => name)
          when Array
            {:name => name, :type => value.shift, :args => value}
        end
      processing_steps.create!(attributes)
    end
  end

  def processing=(value)
    set_processing(value)
  end

  def Upload.width_and_height_for(*dimensions)
    numbers = dimensions.join('x').scan(/\d+/).map{|d| Integer(d)}
    width, height, *ignored = numbers
    [width, height].compact
  end

  module MagickMethods
    def width
      magick[:width]
    end

    def height
      magick[:height]
    end

    def dimensions
      "#{ width }x#{ height }"
    rescue
      nil
    end
  end

  class Variant
    def magick
      MiniMagick::Image.read(data)
    end

    include MagickMethods
  end

  def magick
    original.magick
  end
  include MagickMethods
end
