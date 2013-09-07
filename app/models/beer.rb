class Beer
  include App::Document

  name_fields!

  has_many(:rfis)
end
