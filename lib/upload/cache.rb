###################################################################################
# cache support
###################################################################################

# mount(::Upload::Cache, :upload, :placeholder => 'han-solo.jpg')
#
class Upload
  def Upload.cache!(upload)
    case
      when upload.respond_to?(:read)
        create!(:io => upload, :tmp => true)
      else
        create!(:path => upload.to_s, :tmp => true)
    end
  end

  def cache!(io)
    self.tmp = true
    upload(io)
    save!
    self
  end

  def cache
    id.to_s if persisted?
  end

  class Cache < ::Map
    attr :conducer
    attr :upload
    attr :key

    class << self
      def mount(*args, &block)
        new(*args, &block)
      end
    end

    def initialize(conducer, *args)
      @conducer = conducer
      @options = Map.options_for!(args)
      @key = args.flatten
      @upload = Upload.new :placeholder => @options[:placeholder]

      update(:url => @upload.placeholder.url, :file => nil, :cache => nil)
    end

    def _set(params = {})
      if !params.blank?
        if !params[:file].blank?
          file = params[:file]
          if !params[:cache].blank?
            cache = params[:cache]
            begin
              @upload = Upload.find(cache).cache!(file)
            rescue
              @upload = Upload.cache!(file)
            end
          else
            @upload = Upload.cache!(file)
          end
        else
          if !params[:cache].blank?
            cache = params[:cache]
            begin
              @upload = Upload.find(cache)
            rescue
              nil
            end
          end
        end
      end

      unless @upload.new_record?
        update(
          :url => @upload.url,
          :cache => @upload.cache
        )
      end
    end

    def value
      @upload.id unless @upload.new_record?
    end

    def clear!
      @upload.set(:tmp => false) if @upload.persisted?
    end

    def object
      @upload
    end

    def _key
      @key
    end

    def _value
      @upload
    end

    def _clear
      clear!
    end
  end
end
