class RFI
  include App::Document

  field(:brand, :type => String)
  field(:organization, :type => String)

  field(:email, :type => String)

  field(:first_name, :type => String)
  field(:last_name, :type => String)
  field(:name, :type => String)

  field(:postal_code, :type => String)
  field(:mobile_phone, :type => String)

  field(:location, :type => String)

  before_validation do |rfi|
    rfi.normalize!
  end

  def brand
    read_brand
  end

  def read_brand
    brand = read_attribute(:brand)
    Brand.for(brand) if brand
  end

  def brand=(brand)
    write_brand(brand)
  end

  def write_brand(brand)
    brand = Brand.for(brand)
    write_attribute(:brand, brand ? brand.slug : nil)
    brand
  end

  def normalize!
    normalize_name!
  end

  def normalize_name!
    if self.name.blank?
      name = [first_name, last_name].join(' ')
      self.name = name unless name.blank?
    end

    if self.name.blank?
      name = email.to_s.split(/@/).first.to_s.scan(/\w+/).map(&:titleize).join(' ')
      self.name = name unless name.blank?
    end

    unless self.name.blank?
      parts = self.name.scan(/\w+/)
      first_name = parts.shift
      last_name = parts.pop
      if self.first_name.blank?
        self.first_name = first_name unless first_name.blank?
      end
      if self.last_name.blank?
        self.last_name = last_name unless last_name.blank?
      end
    end
  end
end

Rfi = RFI # shut rails' const missing warning up...
