module App
  module Document
    BSON = (
      case
        when defined?(::Moped::BSON)
          ::Moped::BSON
        when defined?(::BSON)
          ::BSON
      end
    )

    Document.code_for :base do
    ##
    #
      include ::Mongoid::Document



    ## 404 with complex conditions (not simply id)
    #
      def self.not_found!(*args)
        conditions = args.extract_options!.to_options!
        ids = args

        case
          when ids.blank?
            raise ::Mongoid::Errors::DocumentNotFound.new(self, conditions, ids)
          else
            raise ::Mongoid::Errors::DocumentNotFound.new(self, ids, ids)
        end
      end

      def not_found!(*args)
        self.class.not_found!(*args)
      end

    ## lookup helpers
    #
      def self.find_by(conditions)
        where(conditions).first
      end

      def self.find_by!(conditions)
        find_by(conditions) or not_found!(conditions)
      end

    # or||equal docs into existence
    #
      def self.create_or_update(*args)
        attributes = args.shift
        conditions = args.shift || attributes

        created = false

        doc = (
          begin
            where(conditions).first or
            (created = create!(attributes))
          rescue
            where(conditions).first or
            (created = create!(attributes))
          end
        )

        doc.update_attributes(attributes) unless created
        doc
      end

      def self.create_or_update!(*args)
        create_or_update(*args) || not_found!(*args)
      end

    ## code generator for lookup by id and 'field'
    #
    # examples: 
    #   class User
    #     lookup_by! :email
    #   end
    #
    #   - User.for(id)
    #   - User.for(email)
    #   - User.for(user)
    #
      def self.lookup_by!(field)
        field = field.to_s.to_sym

        module_eval <<-__, __FILE__, __LINE__
          def self.for(arg)
            return arg if arg.is_a?(self)

            conditions =
              case arg.to_s
                when Util.patterns[:object_id]
                  {:_id => BSON::ObjectId(arg.to_s)}

                when Util.patterns[:uuid]
                  {:_id => arg.to_s}

                when Util.patterns[:id]
                  {:_id => arg.to_s}

                else
                  pattern = Util.patterns[#{ field.inspect }]

                  if pattern
                    if pattern.match(arg)
                      {#{ field.inspect } => arg}
                    else
                      {}
                    end
                  else
                    {#{ field.inspect } => arg}
                  end
              end

            self.not_found!(arg.inspect) if conditions.empty?
            self.where(conditions).first || self.not_found!(arg.inspect)
          end

          def self.[](arg)
            self.for(arg)
          end

          index({#{ field.inspect } => 1}, :unique => true)
          validates_uniqueness_of(#{ field.inspect })
        __
      end

    ## id lookup helper...
    #
      def self.find_by_id(id)
        where(:_id => id).first
      end

    ## validation shortcut
    #
      def self.validates(attr, &block)
        validates_each(attr) do |doc, attr, value|
          block.call(doc, value)
        end
      end

    ## id casting support
    #
      def self.id_for(model_or_id)
        id = model_or_id.is_a?(Mongoid::Document) ? model_or_id.id : model_or_id

        case id
          when BSON::ObjectId
            id
          else
            BSON::ObjectId(id.to_s)
        end
      end

      def id_for(id)
        self.class.id_for(id)
      end

    ##
    #
      def to_s
        inspect
      end

    ##
    #
      def to_hash(*args)
        as_document
      end

    ##
    #
      def helper
        @helper ||= Helper.new
      end

    ##
    #
      def klass
        self.class
      end
    end
  end
end
