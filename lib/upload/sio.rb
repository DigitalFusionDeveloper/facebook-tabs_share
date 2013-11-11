###################################################################################
# sio support
###################################################################################

class Upload
  class SIO < StringIO
    attr_accessor :pathname

    def initialize(string, options = {})
      string = string.respond_to?(:read) ? string.read : string.to_s
      super(string)
    ensure
      unless options.is_a?(Hash)
        options = {:pathname => options.to_s}
      end

      @pathname = nil 

      [:basename, :pathname, :filename, :path, :file].each do |key|
        break(@pathname = options[key]) if options.has_key?(key)
        break(@pathname = options[key.to_s]) if options.has_key?(key.to_s)
      end

      @pathname ||= Upload.extract_basename(string)
    end

    def basename
      File.basename(pathname)
    end

    def dirname
      File.dirname(pathname)
    end
  end

  def Upload.sio_for(*args, &block)
    SIO.for(*args, &block)
  end

  def SIO.for(*args, &block)
    if args.size == 1 and args.first.is_a?(SIO)
      return args.first
    end

    SIO.new(*args, &block)
  end
end
