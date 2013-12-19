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
    RFI.where(:brand => slug)
  end

  def rfi_fields
    Coerce.list_of_strings(get(:rfi_fields))
  end

  def Brand.rfi_fields
    all.map{|brand| brand.rfi_fields}.flatten.compact.sort.uniq
  end

  def locations
    Location.where(:brand => slug)
  end


  def index_url
    path = Rails.root.join('public', 'brands', slug, 'index.html').to_s

    if test(?e, path)
      "/brands/#{ slug }/index.html".html_safe
    end
  end

  def rfi_url
    "/brands/#{ slug }/contact.html".html_safe
  end

  def locator_url
    case
      when organization.try(:slug) == 'paulaner'
        "/brands/#{ slug }/locator.html".html_safe
      else
        nil
    end
  end

  module Able
    Code = proc do
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
        ensure
          self.organization = self.brand.organization if self.brand
        end

        def organization
          Organization.for(read_attribute(:organization))
        end

        def organization=(organization)
          organization = Organization.for(organization)
          write_attribute(:organization, organization ? organization.id : nil)
        end
    end

    def Able.included(other)
      super
    ensure
      other.module_eval(&Code)
    end
  end

  def Brand.able
    Able
  end
end

#
  Brand.reload!

# dynamically define Brand::Paulaner, Brand::Dixie, etc...
#
  class Brand
    all.each do |brand|
      const = brand.name.camelize
      remove_const(const) if const_defined?(const)
      const_set(const, Module.new)
    end
  end
