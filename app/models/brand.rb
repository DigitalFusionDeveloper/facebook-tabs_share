class Brand
  include App::Document

  name_fields!

  has_many(:rfis)
  field(:organization, :type => String)
  field(:triggered_send_key, :type => String)

  def organization
    super || name
  end
end
