class Brand < Map
#
  def Brand.config_yml
    File.join(Rails.root.to_s, 'config/brands.yml')
  end

  def Brand.config
    Util.load_config_yml(config_yml)
  end

  def Brand.reload!
    Brand.list.clear
    config = Brand.config
    list = Array(config.is_a?(Array) ? config : config['brands'])
    list.map{|attributes| create(attributes)}
    Brand.list
  end

  def Brand.list
    @list ||= []
  end

  def Brand.create(attributes = {})
    brand = Brand.new(attributes)
  ensure
    raise ArgumentError.new(attributes.inspect) if exists?(brand.slug)
    list.push(brand)
    list.sort!
  end

  def Brand.exists?(slug)
    list.detect{|brand| brand.slug == slug.to_s}
  end

  def Brand.for(arg)
    arg = arg.to_s

    list.detect do |brand|
      [brand.title == arg, brand.slug == arg, brand.name == arg].any?
    end
  end

  def Brand.[](arg)
    Brand.for(arg)
  end

#
  Attributes = :title, :slug, :name, :triggered_send_key, :organization

  def initialize(attributes = {})
    Attributes.each{|attr| self[attr] = nil}
    super
  ensure
    normalize!
  end

  def normalize!
    brand = self

    name = brand.name.blank? ? nil : brand.name
    title = brand.title.blank? ? nil : brand.title
    slug = brand.slug.blank? ? nil : brand.slug

    if brand.name.blank?
      case
        when title
          brand.name = Slug.for(title, :join => '_')
        when slug
          brand.name = Slug.for(slug, :join => '_')
      end
    end

    if brand.title.blank?
      case
        when name
          brand.title = String(brand.name).strip.titleize
        when slug
          brand.title = String(brand.slug).strip.titleize
      end
    end

    if brand.slug.blank?
      case
        when name
          brand.slug = Slug.for(name, :join => '-')
        when title
          brand.slug = Slug.for(title, :join => '-')
      end
    end

    unless brand.name.blank?
      brand.name = Slug.for(brand.name, :join => '_')
    end

    unless brand.slug.blank?
      brand.slug = Slug.for(brand.slug, :join => '-')
    end

    unless brand.triggered_send_key.blank?
      brand.triggered_send_key = brand.triggered_send_key.to_s
    end
  end

  def <=>(other)
    self.slug <=> other.slug
  end

  def inspect
    "Brand(#{ to_hash.inspect.chomp })"
  end

  def brand
    self
  end

  def rfis
    RFI.where(:brand => brand.slug)
  end



=begin
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
=end
end

Brand.reload!
