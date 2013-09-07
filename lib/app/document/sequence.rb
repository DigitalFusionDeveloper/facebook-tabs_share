module App
  module Document
    code_for 'app/document/sequence' do
      class << self
        def sequence(fieldname, *args, &block)
          options = args.extract_options!.to_options!

          sequence_name = (
            options.delete(:sequence) || sequence_name_for(fieldname)
          )

          options[:type] ||= Integer

          args.push(options)

          before_validation :on => :create do |doc|
            doc[fieldname] = Sequence.for(sequence_name).next
          end

          field(fieldname, *args, &block)

          Sequence.for(sequence_name)
        end

        alias_method :sequence!, :sequence

        def sequence_for(fieldname)
          Sequence.for(sequence_name_for(fieldname))
        end

        def sequence_name_for(fieldname)
          Sequence.sequence_name_for(self, fieldname)
        end
      end

      def sequence_for(fieldname)
        self.class.sequence_for(fieldname)
      end
    end
  end
end
