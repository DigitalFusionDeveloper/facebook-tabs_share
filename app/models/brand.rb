class Brand < MapModel
#
  attributes :title, :slug, :name, :triggered_send_key, :organization

  identifier :slug

  normalize_names!

  normalize! do
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
    RFI.where(:brand => id)
  end

#
  class Organization < MapModel
    attributes :title, :slug, :name

    identifier :slug

    normalize_names!
  end
end

Brand.reload!
