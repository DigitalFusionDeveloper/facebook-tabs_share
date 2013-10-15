class Brand < MapModel
  attributes :title, :slug, :name, :triggered_send_key, :organization

  def normalize!
    title, slug, name = %w( title slug name ).map{|attr| get(attr)}

    Util.cases_for(title, slug, name).tap do |cases|
      self[:title] = cases.title
      self[:slug] = cases.slug
      self[:name] = cases.name
    end

    self
  end

  def rfis
    RFI.where(:brand => slug)
  end
end

Brand.reload!
