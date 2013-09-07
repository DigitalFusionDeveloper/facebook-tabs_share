module App
  module Document
    code_for 'app/document/name_fields' do
    ## naming support
    #
      def self.name_fields!(*args)
        options = args.extract_options!.to_options!

        %w( name title slug description ).each do |f|
          field(f, :type => String)
        end

        %w( name title slug ).each do |f|
          validates_presence_of(f) unless options[:validate]==false
        end

        before_validation(:on => :create) do |doc|
          name = doc.name.blank? ? nil : doc.name
          title = doc.title.blank? ? nil : doc.title
          slug = doc.slug.blank? ? nil : doc.slug

          if doc.name.blank?
            case
              when title
                doc.name = Slug.for(title, :join => '_')
              when slug
                doc.name = Slug.for(slug, :join => '_')
            end
          end

          if doc.title.blank?
            case
              when name
                doc.title = String(doc.name).strip.titleize
              when slug
                doc.title = String(doc.slug).strip.titleize
            end
          end

          if doc.slug.blank?
            case
              when name
                doc.slug = Slug.for(name, :join => '-')
              when title
                doc.slug = Slug.for(title, :join => '-')
            end
          end

          unless doc.name.blank?
            doc.name = Slug.for(doc.name, :join => '_')
          end

          unless doc.slug.blank?
            doc.slug = Slug.for(doc.slug, :join => '-')
          end

          unless doc.description.nil?
            doc.description = doc.description.to_s.strip
          end
        end
      end
    end
  end
end
