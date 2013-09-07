module App
  module Document
    code_for 'app/document/string_ids' do
    ## life gets harder when the id isn't a string...
    #

=begin
      def ::App::Document.generate_id(*args, &block)
        BSON::ObjectId.new.to_s
      end

      field(:_id, :type => String, :default => proc{ App::Document.generate_id })

      if respond_to?(:identity)
        begin
          identity(:type => String, :default => proc{ App::Document.generate_id })
        rescue
          nil
        end
      end

      if respond_to?(:using_object_ids)
        self.using_object_ids = false
      end

      module ::Mongoid
        class Identity
          def generate_id
            App::Document.generate_id
          end
        end
      end
=end
    end
  end
end
