class RFI
#
  include App::Document

  include Brand.able

  def RFI.report_fields
    %w( id kind organization brand ) + Coerce.list_of_strings(Brand.rfi_fields).sort
  end
end

Rfi = RFI # shut rails' const missing warning up...
