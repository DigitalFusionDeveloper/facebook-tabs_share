class Organization < MapModel
  attributes :title, :slug, :name

  identifier :slug

  normalize_names!

  def brands
    Brand.all.select {|b| b.organization.slug == slug }
  end
end
