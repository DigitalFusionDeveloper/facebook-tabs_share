module App
  module Document
    code_for 'app/document/filtered_fields' do
      class << self
        def filtered_fields
          @filtered_fields ||= []
        end

        def filtered_field_filters
          @filtered_field_filters ||= %w( markdown md html erb eruby ) 
        end

        def filtered_field(field, *args)
          field        = "#{ field }"
          field_source = "#{ field }_source"
          field_filter = "#{ field }_filter"

          filter = args.shift || :md

          class_eval <<-__, __FILE__, __LINE__
            field #{ field.inspect }, :type => String
            field #{ field_source.inspect }, :type => String
            field #{ field_filter.inspect }, :type => String, :default => #{ filter.inspect }

            def #{ field }
              read_attribute(#{ field.inspect }).to_s.html_safe
            end

            def #{ field }=(value)
              write_attribute(#{ field_source.inspect }, value)
            end
          __

          filtered_fields.push(field).uniq!

          validates_inclusion_of(field_filter, :in => filtered_field_filters)

          field
        end

        def filter(source, filter)
          return nil if source.blank?

          Util.tidy(View.render(:inline => source, :type => filter))
        end
      end

      def process_filtered_fields!
        doc = self
        klass = doc.class

        klass.filtered_fields.each do |field|
          source = doc.send("#{ field }_source")
          filter = doc.send("#{ field }_filter")
          
          filtered = klass.filter(source, filter)

          if filtered.blank?
            doc.write_attribute("#{ field }", nil)
            doc.write_attribute("#{ field }_source", nil)
          else
            doc.write_attribute("#{ field }", filtered)
          end
        end
      end

      before_validation do |doc|
        doc.process_filtered_fields!
      end
    end
  end
end
