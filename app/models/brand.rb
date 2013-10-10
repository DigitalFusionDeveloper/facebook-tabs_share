class Brand
  include App::Document

  name_fields!

  has_many(:rfis)
  field(:triggered_send_key, :type => String)

end
