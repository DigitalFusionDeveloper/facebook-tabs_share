class RFI
#
  include App::Document

#
  field(:brand, :type => String)
  field(:organization, :type => String)

#
  index({:brand => 1})
  index({:organization => 1})

#
  def brand
    Brand.for(read_attribute(:brand))
  end

  def brand=(brand)
    brand = Brand.for(brand)
    write_attribute(:brand, brand ? brand.id : nil)
  end

  def organization
    Organization.for(read_attribute(:organization))
  end

  def organization=(organization)
    organization = Organization.for(organization)
    write_attribute(:organization, organization ? organization.id : nil)
  end


  def RFI.report_fields
    Coerce.list_of_strings(:brand, :organization, Brand.rfi_fields)
  end
end

Rfi = RFI # shut rails' const missing warning up...
