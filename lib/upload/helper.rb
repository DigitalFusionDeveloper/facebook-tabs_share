class Upload
  module Helper
    def upload_path(*args)
    #
      options = args.extract_options!.to_options!

    #
      arg = args.shift || options.delete(:id) || options.delete(:upload) or raise(ArgumentError, 'no upload or id')
      if arg.is_a?(Upload)
        upload = arg
        id = upload.id
      else
        id = arg
        upload = Upload.find(id)
      end

    #
      arg = args.shift || options.delete(:variant) || options.delete(:name)
      if arg
        name = arg
      else
        name = nil
      end

    #
      return upload.url_for(name)
    end

    def upload_query_string_for(query, options = {})
      options.to_options!
      escape = options.has_key?(:escape) ? options[:escape] : true
      pairs = [] 
      esc = escape ? proc{|v| CGI.escape(v.to_s)} : proc{|v| v.to_s}
      query.each do |key, values|
        key = key.to_s
        values = [values].flatten
        values.each do |value|
          value = value.to_s
          if value.empty?
            pairs << [ esc[key] ]
          else
            pairs << [ esc[key], esc[value] ].join('=')
          end
        end
      end
      pairs.replace pairs.sort_by{|pair| pair.size}
      query_string = pairs.join('&')
      query_string.blank? ? nil : query_string
    end
  end
end
