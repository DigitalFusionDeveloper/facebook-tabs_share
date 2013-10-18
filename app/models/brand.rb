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

  def rfi_fields
    Coerce.list_of_strings(get(:rfi_fields))
  end

  def Brand.rfi_fields
    all.map{|brand| brand.rfi_fields}.flatten.compact.sort.uniq
  end
end

Brand.reload!
