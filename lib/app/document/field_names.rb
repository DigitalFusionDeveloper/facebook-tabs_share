module App
  module Document
    code_for 'app/document/field_names' do
    # we remember the order in which fields are declared so we can do things
    # like represent documents in ordered containers
    #
      def self.destructive_fields
        @destructive_fields ||= ::Mongoid.destructive_fields.map(&:to_s)
      end

      def self.field(*args, &block)
        name = args.first.to_s

        whitelist = %w( _id _type )
        blacklist = destructive_fields

        if blacklist.include?(name) and !whitelist.include?(name)
          raise ArgumentError.new("FAIL! #{ name } is a Mongoid.destructive_field")
        end

        field_names.push(name)

        last = %w( created_at updated_at )
        last.each do |f|
          unless name == f
            field_names.delete(f)
            field_names.push(f)
          end
        end

        field_names.uniq!
        super
      end

      def self.field_names
        @field_names ||= (
          field_names =
            ancestors[1..-1].map do |ancestor|
              if ancestor.respond_to?(:field_names)
                ancestor.field_names
              else
                []
              end
            end.flatten.compact
        )
      end

      def field_names
        self.class.field_names
      end

      def self.embeds_many(*args)
        super
      ensure
        name = args.first.to_s
        field_names.push(name)
        field_names.uniq!
      end

      def self.embeds_one(*args)
        super
      ensure
        name = args.first.to_s
        field_names.push(name)
        field_names.uniq!
      end
    end
  end
end
