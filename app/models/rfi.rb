class RFI
#
  include App::Document

  include Brand.able

  def RFI.report_fields
    Coerce.list_of_strings(:brand, :organization, Brand.rfi_fields)
  end
end

Rfi = RFI # shut rails' const missing warning up...
