class RFI
  include App::Document

  belongs_to(:beer)
  field(:beer_name, :type => String)

  field(:name, :type => String)
  field(:email, :type => String)
  field(:postal_code, :type => String)
  field(:mobile_phone, :type => String)

  before_validation do |rfi|
    if rfi.beer_name.nil? and rfi.beer
      rfi.beer_name ||= rfi.beer.name
    end
  end
end

Rfi = RFI # shut rails' const missing warning up...
