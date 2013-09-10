class RFI
  include App::Document

  field(:beer_slug, :type => String)

  field(:email, :type => String)

  field(:first_name, :type => String)
  field(:last_name, :type => String)
  field(:name, :type => String)

  field(:postal_code, :type => String)
  field(:mobile_phone, :type => String)

  belongs_to(:beer)

  before_validation do |rfi|
    rfi.normalize!
  end

  def normalize!
    normalize_beer!
    normalize_name!
  end

  def normalize_beer!
    if self.beer_slug.nil? and self.beer
      self.beer_slug ||= self.beer.slug
    end
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
