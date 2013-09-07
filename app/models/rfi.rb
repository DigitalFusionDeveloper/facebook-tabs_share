class RFI
  include App::Document

  field(:beer_slug, :type => String)

  field(:name, :type => String)
  field(:email, :type => String)
  field(:postal_code, :type => String)
  field(:mobile_phone, :type => String)

  belongs_to(:beer)

  before_validation do |rfi|
    if rfi.beer_slug.nil? and rfi.beer
      rfi.beer_slug ||= rfi.beer.slug
    end
  end
end

Rfi = RFI # shut rails' const missing warning up...
