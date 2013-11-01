class BrandsController < ::ApplicationController
  def show
    @brand = Brand.for(params[:id])

    if @brand
      public_path = Rails.root.join('public', 'brands', @brand.slug, 'index.html')

      if test(?d, public_path)
        redirect_to(public_path, :status => :moved_permanently)
        return
      end
    end

    render(:nothing => true, :status => 404)
  end
end
