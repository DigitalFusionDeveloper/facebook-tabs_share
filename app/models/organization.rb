class Organization < MapModel
  attributes :title, :slug, :name

  identifier :slug

  normalize_names!
end
