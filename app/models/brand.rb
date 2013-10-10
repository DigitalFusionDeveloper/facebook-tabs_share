class Brand
  include App::Document

  name_fields!

  field(:organization, :type => String)
  field(:triggered_send_key, :type => String)

  has_many(:rfis)

  before_validation do |brand|
    brand.normalize!
  end

  def normalize!
    brand = self

    if brand.organization.blank?
      brand.organization = %w( name title slug ).map{|attr| brand[attr]}.compact.first
    end
  end
end
