class ::DirectoryImporter < Dao::Conducer
  class << self
    def model_class(*args)
      unless args.empty?
        self.model_class = args.shift
      end

      @model_class ||= (
        parts = name.split(/::/)
        parent_class = eval(parts.slice(0..-2).join('::'))
      )
    end

    def model_class=(model_class)
      @model_class = model_class
    end

    def model_scope_for(prefix, path)
      model_class.all
    end

    def model_for(prefix, path, options = {})
      options.to_options!

      path = path.to_s
      basename = File.basename(path)

      slug = Slug.for(basename)
      name = Slug.for(name, :join => '_')
      title = name.titleize

      attributes_yml = File.join(prefix, path, 'attributes.yml')

      if File.exist?(attributes_yml)
        attributes = Map.new(YAML.load(IO.read(attributes_yml).force_encoding('utf-8')))

        slug = attributes.get(:slug) if attributes.has_key?(:slug)
        name = attributes.get(:name) if attributes.has_key?(:name)
        title = attributes.get(:title) if attributes.has_key?(:title)
      end

      queries = [
        {:slug => slug},
        {:name => name},
        {:title => title}
      ]

      scope = model_scope_for(prefix, path)

      model = nil

      queries.each do |query|
        model = scope.where(query).first
        break if model
      end

      model || scope.new
    end

    def for(prefix, path, options = {})
      model = model_for(prefix, path, options)
      importer = new(prefix, path, model)
      importer.fresh = false if options[:force]
      importer
    end

    def imports?(directory)
      globs = [
        'attributes.yml'
      ]

      globs.any? do |glob|
        Dir.glob(File.join(directory, glob)).size > 0
      end
    end

    attr_accessor :root
  end

  def initialize(prefix, path, *args)
    @prefix = prefix.to_s
    @path = path.to_s
    @directory = File.expand_path(File.join(@prefix, @path))

    model = args.detect{|arg| arg.respond_to?(:persisted?)}

    model ||= self.class.model_for(@prefix, @path)

    set_model(model)

    @asset_processor = AssetProcessor.new(@directory, :builder => self)
    @basename = File.basename(@directory)
    @slug = Slug.for(@basename)
    @imported = false
    @uploads = []
  end

  def process_directory!
  #
    File.stat(@directory)

  #
    updated_at = 
      if model.persisted?
        model.updated_at rescue Time.at(0).utc
      else
        Time.at(0).utc
      end

  #
    attributes_yml = File.join(@directory, 'attributes.yml')
    if File.exist?(attributes_yml)
      if newer?(attributes_yml, updated_at)
        hash = YAML.load(IO.read(attributes_yml).force_encoding('utf-8'))
        attributes.update(hash)
      end
    end

  #
    @slug = Slug.for(attributes.get(:slug) || @basename)

  #
    ensure_uploads! do |file, upload|
      relative_path = relative_path_for(file, @directory)
      depth = relative_path.split('/').size

      if depth == 1
        parts = File.basename(file).split('.')
        name = parts.first
        attributes.set(name, upload)
      end
    end

  #
    glob = Dir.glob(File.join(@directory, '*.{html,html.erb,md,markdown,yml,yaml}'))

    Dir.glob(glob).each do |file|
      next unless test(?f, file)
      next unless newer?(file, updated_at)

      basename = File.basename(file)
      next if basename == 'attributes.yml'

      parts = basename.split('.')

      filtered_attribute = parts.first

      filtered_attribute_source = "#{ filtered_attribute }_source"
      filtered_attribute_filter = "#{ filtered_attribute }_filter"

      next unless(
        model.respond_to?(filtered_attribute + '=') or
        model.respond_to?(filtered_attribute_source + '=') or
        model.respond_to?(filtered_attribute_filter + '=')
      )

      source = IO.read(file)
      filtered_source = @asset_processor.process(source)
      filter = parts.last

      case
        when model.respond_to?(filtered_attribute_source + '=')
          attributes.set(filtered_attribute_source, filtered_source)

        when model.respond_to?(filtered_attribute + '=')
          attributes.set(filtered_attribute, filtered_source)
      end

      case
        when model.respond_to?(filtered_attribute_filter + '=')
          attributes.set(filtered_attribute_filter, filter)
      end
    end

    attributes
  end

  def upload_for(path)
    source = relative_path_for(path.to_s, Rails.root)

    upload = Upload.where(:context => @model, :key => source, :tmp => false).first

    created = false

    if upload
      if newer?(path, upload.updated_at)
        src_data = IO.read(path).force_encoding('binary')
        dst_data = upload.variants.first.data.force_encoding('binary')

        if src_data != dst_data
          upload.variants.destroy_all
          upload.upload!(path)
          created = true
#binding.pry
        end
      end
    else
      upload = Upload.upload!(path)
      created = true
#binding.pry
    end

    upload.update_attributes(:context => @model) unless upload.context == @model
    upload.update_attributes(:key => source) unless upload.key == source
    upload.update_attributes(:tmp => false) unless upload.tmp == false
                
    if upload.image?
      sizes = upload.variants.map(&:name)
      Upload.create_sizes!(upload) if sizes == ["original"]
    end

    upload.touch

    if created
      @uploads.push(upload) unless @uploads.include?(upload)
    end

    upload
  end

# asset_processor interface
#
  def asset_for(*args, &block)
    upload_for(*args, &block)
  end

  def url_for(asset)
    URI.parse(asset.url).path
  end

  def ensure_uploads!(&block)
    results = []

    glob = Dir.glob(File.join(@directory, '**/*.{png,jpg,jpeg,gif,tiff}'))

    Dir.glob(glob) do |file|
      upload = upload_for(file)
      block ? block.call(file, upload) : results.push([file, upload])
    end

    block ? nil : results
  end

  def model_name
    model.class.model_name
  end

  def newer?(a, b)
    a = a.is_a?(Time) ? a : File.stat(a).mtime
    b = b.is_a?(Time) ? b : File.stat(b).mtime
    a > b
  end

  def relative_path_for(file, directory)
    Pathname.new(file.to_s).relative_path_from(Pathname.new(directory.to_s)).to_s
  end

  def model_attributes
    model_attributes = attributes.dup
  end

  def save
    if fresh?
      model.touch
      return true
    end

    process_directory!

    return false unless valid?

    if save_model
      @imported = true
      saved = true
    else
      errors.relay(model.errors)
      saved = false
    end
  end

  def save_model
    model_attributes.each do |name, value|
      begin
        model.send("#{ name }=", value)
      rescue
        abort("failed setting #{ name }=#{ value.inspect }\nfrom #{ model_attributes.inspect }\non #{ model.inspect }")
      end
    end

    model.save
  end

  def fresh?
    if defined?(@fresh)
      return !!@fresh
    end

    unless model.persisted?
      return false
    else
      glob = File.join(@directory, '**/**')

      Dir.glob(glob) do |entry|
        if File.stat(entry).mtime.utc > model.updated_at.utc
          return false
        end
      end

      return true
    end
  end

  def fresh
    if defined?(@fresh)
      @fresh
    end
  end

  def fresh=(fresh)
    @fresh = !!fresh
  end

  def imported?
    !!@imported
  end

  after_save do |saved|
    if not saved
      @uploads.map(&:destroy)
    end

    if not saved and errors.empty?
      errors.add 'wtf!?'
    end
  end
end
