class Upload
##
#
  class << Upload
    fattr(:default_url_options){
      defined?(DefaultUrlOptions) ? DefaultUrlOptions : Map.new
    }

    [:protocol, :host, :port].each do |key|
      fattr(key){ DefaultUrlOptions[key] }
    end

    def base_href(options = {})
      options = options.to_options!

      protocol = options.has_key?(:protocol) ? options[:protocol] : (Upload.protocol || 'http')
      host = options.has_key?(:host) ? options[:host] : (Upload.host || '0.0.0.0')
      port = options.has_key?(:port) ? options[:port] : (Upload.port || (Upload.host == '0.0.0.0' ? 3000 : nil))

      base_href = []
      if protocol and host
        protocol = protocol.to_s.split(/:/, 2).first 
        base_href << protocol
        base_href << "://#{ host }"
      else
        base_href << "//#{ host }"
      end
      if port
        base_href << ":#{ port }"
      end
      base_href.join
    end

    def url_for(*args)
      options = args.extract_options!.to_options!

      path_info = options.delete(:path_info) || options.delete(:path)
      query_string = options.delete(:query_string)
      fragment = options.delete(:fragment) || options.delete(:hash)
      query = options.delete(:query) || options.delete(:params)

      raise(ArgumentError, 'both of query and query_string') if query and query_string

      args.push(path_info) if path_info

      path_info = Upload.absolute_path_for(*args)

      if options.delete(:absolute) || options.delete(:only_path)==false
        base_href = Upload.base_href(options)
        url = base_href + path_info
      else
        url = path_info
      end

      url += ('?' + query_string) unless query_string.blank?
      url += ('?' + query.query_string) unless query.blank?
      url += ('#' + fragment) if fragment
      url
    end
  end

##
#
  class Variant
    def url_for(*args, &block)
      Upload.url_for(path_info, *args, &block)
    end
    alias_method('url', 'url_for')


    def fs_url(*args, &block)
      return nil unless fs?

      Upload.url_for(path_info, *args, &block)
    end

    def grid_fs_url(*args, &block)
      return nil unless grid_fs?

      Upload.url_for(path_info, *args, &block)
    end

    def s3_url(*args, &block)
      return nil unless s3?

      case
        when args.empty?
          args.unshift(:read)
          s3_object.url_for(*args, &block).to_s.split('?').first

        when args.size == 1 && args.last.is_a?(Hash)
          args.unshift(:read)
          s3_object.url_for(*args, &block).to_s

        else
          s3_object.url_for(*args, &block).to_s
      end
    end

    def path_info
      Upload.absolute_path_for(
        case
          when s3?
            s3['key']

          when grid_fs?, fs?
            "#{ Upload.route }/#{ upload.id }/#{ name }/#{ basename }"
        end
      )
    end
    alias_method('path', 'path_info')
    alias_method('path_for', 'path_info')
  end
end
