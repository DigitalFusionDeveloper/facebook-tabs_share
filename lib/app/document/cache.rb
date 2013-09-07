module App
  module Document
    Document.code_for :cache do
      def self.cache_extensions
        @cache_extensions ||= Map.new
      end

      def self.build_cached(model, name, attributes)
        extension = cache_extensions[name]
        doc = model.instantiate(attributes)
        doc.extend(extension) if extension
        doc
      end

      def self.caches_one(name, *args, &block)
        options = args.extract_options!.to_options!

        name     = name.to_s
        singular = name.singularize
        plural   = singular.pluralize
        model    = (options[:class_name] || singular.camelize).to_s.constantize
        accessor = name

        cache_extensions[name] = block if block

        class_eval <<-__, __FILE__, __LINE__
          field(:#{ accessor }_id)
          field(:#{ accessor }_cache, :type => Hash)

          def #{ accessor }
            unless #{ accessor }_cache.blank?
              @#{ accessor } ||= (
                attributes = #{ accessor }_cache
                doc = self.class.build_cached(#{ model }, '#{ name }', attributes)
              )
            end
          end

          def #{ accessor }=(value)
            cache_#{ accessor }!(value)
          end

          def #{ accessor }_id=(id)
            value =
              unless id.blank?
                #{ model }.find(id)
              else
                nil
              end
            cache_#{ accessor }!(value)
          end

          def cache_#{ accessor }!(value)
            @#{ accessor } = nil

            unless value.blank?
              cache = value.respond_to?(:as_document) ? value.as_document : value
              self['#{ accessor }_cache'] = cache
              self['#{ accessor }_id'] = #{ accessor }.id
            else
              self['#{ accessor }_cache'] = nil
              self['#{ accessor }_id'] = nil
            end
          end
        __
      end

      def self.caches_many(name)
        name     = name.to_s
        singular = name.singularize
        plural   = singular.pluralize
        model    = (options[:class_name] || singular.camelize).to_s.constantize
        accessor = name

        code = <<-__

          field(:#{ accessor }_ids, :type => Array)
          field(:#{ accessor }_cache, :type => Array)

          def #{ accessor }
            unless #{ accessor }_cache.blank?
              @#{ accessor } ||= (
                #{ accessor }_cache.map do |attributes|
                  doc = self.class.build_cached(#{ model }, '#{ name }', attributes)
                end
              )
            end
          end

          def #{ accessor }=(*values)
            cache_#{ accessor }!(values.flatten.compact)
          end

          def cache_#{ accessor }!(values)
            @#{ accessor } = nil

            array_of_documents =
              values.flatten.compact.map do |value|
                value.respond_to?(:as_document) ? value.as_document : value
              end

            self.#{ accessor }_cache = array_of_documents.compact

            self.#{ accessor }_ids = #{ accessor }.map{|doc| doc.id}
          end

        __

        begin
          class_eval(code)
        rescue Object
          raise SyntaxError, code
        end
      end


    end
  end
end
