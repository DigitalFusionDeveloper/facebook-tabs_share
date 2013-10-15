class Brand < MapModel
#
  include Naming

  attributes :title, :slug, :name, :triggered_send_key, :organization

  normalize do
    org = self[:organization]

    unless org.nil?
      organization = Organization.for(org)

      if organization.nil?
        organization = Organization.create(:title => org)
      end

      self[:organization] = organization
    end
  end

#
  def rfis
    RFI.where(:brand => slug)
  end

#
  class Organization < MapModel
    include Naming

    attributes :title, :slug, :name

    def normalize!
      title, slug, name = %w( title slug name ).map{|attr| get(attr)}

      Util.cases_for(title, slug, name).tap do |cases|
        self[:title] = cases.title
        self[:slug] = cases.slug
        self[:name] = cases.name
      end

      self
    end
  end
end

Brand.reload!
