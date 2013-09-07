module App
  module Document
    Document.code_for :enum_cache do

      def self.enum_cache_for(enum, value)
        unless value.blank?
          case
            when value.respond_to?(:as_document)
              value.as_document
            else
              enum_name = enum.is_a?(::Enum) ? enum.name : enum.to_s
              value_name = value.is_a?(::Enum::Value) ? value.name : value.to_s
              ::Enum[enum_name][value_name].as_document
          end
        else
          nil
        end
      end

      def self.caches_one_enum(name, *args, &block)
        options = args.extract_options!.to_options!

        name      = name.to_s
        singular  = name.singularize
        plural    = singular.pluralize
        enum_name = (options[:enum_name] || singular.underscore)
        accessor  = name


        cache_extensions[name] = block if block

        class_eval <<-__, __FILE__, __LINE__
          field(:#{ accessor }_id)
          field(:#{ accessor }_cache, :type => Hash)

          def #{ accessor }
            unless #{ accessor }_cache.blank?
              @#{ accessor } ||= (
                attributes = #{ accessor }_cache
                doc = self.class.build_cached(::Enum::Value, '#{ name }', attributes)
              )
            end
          end

          def #{ accessor }=(value)
            cache_#{ accessor }!(value)
          end

          def #{ accessor }_enum
            ::Enum['#{ enum_name }']
          end

          def #{ accessor }_id=(arg)
            cache_#{ accessor }!(arg)
          end

          def cache_#{ accessor }!(value)
            @#{ accessor } = nil

            unless value.blank?
              cache = self.class.enum_cache_for('#{ enum_name }', value)

              self['#{ accessor }_cache'] = cache
              self['#{ accessor }_id'] = #{ accessor }.id
            else
              self['#{ accessor }_cache'] = nil
              self['#{ accessor }_id'] = nil
            end
          end
        __
      end

      def self.caches_many_enums(name, *args, &block)
        options = args.extract_options!.to_options!

        name      = name.to_s
        singular  = name.singularize
        plural    = singular.pluralize
        enum_name = (options[:enum_name] || singular.underscore)
        accessor  = name

        class_eval <<-__, __FILE__, __LINE__
          field(:#{ accessor }_ids, :type => Array)
          field(:#{ accessor }_cache, :type => Array)

          def #{ accessor }
            unless #{ accessor }_cache.blank?
              @#{ accessor } ||= (
                #{ accessor }_cache.map do |attributes|
                  doc = self.class.build_cached(::Enum::Value, '#{ name }', attributes)
                end
              )
            end
          end

          def #{ accessor }_enum
            ::Enum['#{ enum_name }']
          end

          def #{ accessor }=(*values)
            cache_#{ accessor }!(values.flatten.compact)
          end

          def cache_#{ accessor }!(values)
            @#{ accessor } = nil

            array_of_documents =
              Array(values).flatten.compact.map do |value|
                cache = self.class.enum_cache_for('#{ enum_name }', value)
              end

            self.#{ accessor }_cache = array_of_documents.compact
            self.#{ accessor }_ids = #{ accessor }.map{|doc| doc.id}
          end
        __
      end

    end
  end
end
