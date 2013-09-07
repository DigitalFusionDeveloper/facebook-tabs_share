module App
  module Document
    def Document.to_map(doc, *args, &block)
      options = args.extract_options!.to_options!
      fields = args

      if fields.blank?
        fields = doc.to_map_fields
      end

      relations = options[:relations] || options[:include]

      case relations
        when Array, String, Symbol
          relations = Coerce.list_of_strings(relations)
          fields.push(*relations)
      end

      map = Map.new
      map[:id] ||= doc._id.to_s
      map[:_id] ||= doc._id.to_s

      fields.each do |field|
        value = doc.send(field)

        case value
          when ::Mongoid::Relations::Proxy
            if relations
              if value.respond_to?(:map)
                value = value.map{|v| to_map_convert(v)}
              else
                value = to_map_convert(value)
              end

              map[field] = value
            end

          when Array
            if value.respond_to?(:map)
              value = value.map{|v| to_map_convert(v)}
            else
              value = to_map_convert(value)
            end

            map[field] = value

          else
            value = to_map_convert(value)

            map[field] = value
        end
      end

      map
    end

    def Document.to_map_convert(object, options = {})
      case
        when object.respond_to?(:to_map)
          Util.call(object, :to_map, options)
        else
          object
      end
    end

    code_for 'app/document/to_map' do
      def to_map_fields
        @to_map_fields ||= (
          (self.class.field_names + attributes.keys + [:_id]).
            map{|k| k.to_s}.
            uniq.
            partition{|k| k !~ /^_/}.
            flatten.
            compact
        )
      end

      def to_map(*args, &block)
        App::Document.to_map(self, *args, &block)
      end

      def as_json(*args, &block)
        to_map(*args, &block)
      end

      def inspect(*args)
        to_map.inspect
      end
    end
  end
end
