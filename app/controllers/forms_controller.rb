class FormsController < ::ApplicationController
#
  layout 'forms'
  prepend_view_path 'app/views/brands'
  before_filter 'setup'

#
  def rfi
    conducer =
      case
        when @brand.organization.slug == 'paulaner'
          RFI::PaulanerConducer

        when @brand.slug == 'cus'
          RFI::CCUConducer

        else
          raise IndexError.new(@brand.inspect)
      end

    conducer.render!
  end

protected
#
  def setup
    @brand = Brand.for(:slug => params[:brand])

    if @brand.nil?
      render(:text => "brand #{ params[:brand].inspect } not found", :status => 404)
    end

    @tab = params["tab"] || request.env["HTTP_REFERER"]
  end

  fattr(:tab)
  alias_method(:current_tab, :tab)
  helper_method(:tab)
  helper_method(:current_tab)
end
