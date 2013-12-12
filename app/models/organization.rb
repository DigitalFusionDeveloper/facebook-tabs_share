Brand # hack to ensure brands are loaded...

class Organization < MapModel
  attributes :title, :slug, :name

  identifier :slug

  normalize_names!

  def brands
    Brand.all.select {|b| b.organization.slug == slug }
  end
end

# dynamically define Brand::Paulaner, Brand::Dixie, etc...
#
  class Organization
    all.each do |organization|
      const = organization.name.camelize
      remove_const(const) if const_defined?(const)
      const_set(const, Module.new)
    end
  end
