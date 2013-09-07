class AssetProcessor < ::Array
  def initialize(directory, options = {})
    options.to_options!

    @directory = directory
    @keys = []
    @map = Map.new
    @re = nil

    @builder = options[:builder]

    scan_directory!
  end

  def clear
    super
    @keys.clear
    @map.clear
    @re = nil
  end

  def assets
    self
  end

  def scan_directory!
    clear

    Dir.glob(File.join(@directory, 'assets/*')).each do |entry|
      next unless test(?f, entry)

      path = File.expand_path(entry)
      path, basename = File.split(path)
      path, dirname = File.split(path)

      key = File.join(dirname, basename)
      @keys.push(key)
    end

    @re = @keys.map{|key| '(\b%s\b)' % Regexp.escape(key)}.join('|')
    @re = %r/#{ @re }/i
  end

  def process(source)
    return source if @keys.empty?

    chunks = source.split(@re)

    previous = nil

    chunks.each do |chunk|
      key = @keys.detect{|k| k == chunk}

      if key
        is_relative_path = previous[-1] != '/' || previous.nil?

        if is_relative_path 
          asset = nil
          pathname = File.join(@directory, key)

          if @map[key].nil?
            asset = build_asset(pathname)
            push(asset)
          else
            asset = @map[key]
          end

          url = build_url(asset)

          chunk.replace(url)
        end
      end

      previous = chunk
    end

    source = chunks.join
  end

  def build_url(asset)
    if @builder
      @builder.url_for(asset).to_s
    else
      asset.url.to_s
    end
  end

  def build_asset(pathname)
    if @builder
      @builder.asset_for(pathname)
    else
      Upload.upload!(pathname).tap do |asset|
        Upload.create_sizes!(asset)
      end
    end
  end

  def destroy_all
    all?{|asset| asset.destroy}
  end

  alias_method('destroy', 'destroy_all')
end
