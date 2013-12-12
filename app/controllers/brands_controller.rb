class BrandsController < ::ApplicationController
  before_filter(:setup)

  include Tagz

  layout false

  def index
    html = 
      tagz{
        ul_{
          Brand.all.each do |brand|
            li_{ a_(:href => brand_url(brand)){ [brand.organization, brand].compact.join('/') } }
          end
        }
      }
    render :inline => html, :layout => 'application' 
  end

  def show
    public_path = Rails.root.join('public', 'brands', @brand.slug, 'index.html')

    if test(?d, public_path)
      redirect_to(public_path + '/', :status => :moved_permanently)
      return
    end
  end

  def locator
    case
      when @brand.organization.slug == "paulaner"
        require_dependency 'app/conducers/organizations/paulaner/locator_conducer.rb'
        Organization::Paulaner::LocatorConducer.render!
      else
        render(:nothing => true, :status => 404)
    end
  end

protected
  def setup
    unless params[:id].blank?
      @brand = Brand.for(params[:id])

      unless @brand
        render(:nothing => true, :status => 404)
      end
    end
  end

  def brand_url(brand)
    File.join('brands', brand.slug) + '/'
  end
end
