Object.send(:remove_const, :Placeholder) if Object.const_defined?(:Placeholder)

class Placeholder
  Path = File.join(Rails.root, 'app', 'assets', 'images', 'placeholders')
  Url = '/assets/placeholders'

  attr_accessor :basename
  attr_accessor :base
  attr_accessor :ext
  attr_accessor :content_type
  attr_accessor :path
  attr_accessor :pathname
  attr_writer :url

  def initialize(basename)
    @basename = basename.to_s
    @base, @ext = @basename.split('.', 2)
    @content_type = Placeholder.extract_content_type(@basename)
    @url = File.join(Url, @basename)
    @path = File.join(Path, @basename)
    @pathname = Pathname.new(path)
    File.stat(@path) unless Rails.env.production?
  end

  def to_upload
    key = url

    upload = ::Upload.where(:key => key).first

    unless upload
      begin
        open(path, 'rb') do |io|
          upload = ::Upload.upload!(io)

          upload.update_attributes!(:key => key)

          upload.set_processing(
            :large  => [:resize, '640x', {:enlarge => false}],
            :medium => [:resize, '320x', {:enlarge => false}],
            :small  => [:resize, '50x', {:enlarge => false}]
          )

          Job.submit(Upload, :process, upload.id)

          upload
        end
      rescue Object => e
        nil
      end
    end

    upload ||= ::Upload.where(:key => key).first

    raise "failed to upload #{ path }" unless upload

    upload
  end

  def url(*args)
    @url.html_safe
  end

  def to_s(*args)
    url(*args)
  end

  def dirname
    pathname.dirname
  end

  Cache = Map.new

  def Placeholder.for(basename)
    Placeholder.create(basename)
  end

  def Placeholder.create(basename)
    base, ext = basename.to_s.split('.', 2)
    Cache[base] ||= Placeholder.new(basename)
  end

  class Error < ::StandardError; end

  def Placeholder.method_missing(method, *args, &block)
    if args.empty? and block.nil?
      base = method.to_s
      candidates = Placeholder.glob(base).map{|candidate| File.basename(candidate)}
      case candidates.size
        when 0
          super
        when 1
          return Placeholder.create(candidates.first)
        else
          raise(Error, candidates.join(', '))
      end
    end
    super
  end

  def Placeholder.glob(base, &block)
    results = []

    Dir.glob(File.join(Path, "#{ base }.*")) do |entry|
      next unless test(?e, entry)
      block ? block.call(entry) : results.push(File.expand_path(entry))
    end

    block ? nil : results
  end

  def Placeholder.extract_content_type(filename)
    content_type = MIME::Types.type_for(::File.basename(filename.to_s)).first
    content_type.to_s if content_type
  end
end
