class FormsController < ::ApplicationController
##
#
  layout 'forms'
  prepend_view_path 'app/views/brands'
  before_filter 'set_brand'

##
#

  def rfi
    # FIXME: Need logic to pick the right conducer
    @form = RFIConducer.for(@brand, @brand.rfis.new, params[:rfi])

binding.pry

    unless request.get?
      if @form.save
        @form.form.messages.success("Thanks #{ @form.email }!")
      else
=begin
      @form.errors.each do |key, list|
        title = key.split('.').last.titleize
        errors = list.join(', ')
        @form.form.messages.error("#{ title }: #{ errors }")
      end
=end
      end
    end

    render @form.template
  end

protected
##
#
  def set_brand
    @brand = Brand.for(:slug => params[:brand])
  end

##
#
  class RFIConducer < ::Dao::Conducer
    model_name :rfi

    attr_accessor :brand
    attr_accessor :rfi

    def initialize(brand, rfi, params = {})
      @brand = brand
      @rfi = rfi

      update_attributes(
        @rfi.attributes
      )

      update_attributes(
        params
      )
    end

    def save
      @rfi.brand_slug = @brand.slug

      unless attributes.email.to_s.split(/@/).size == 2
        errors.add(:email, 'is invalid')
      end

      return false unless valid?

      attributes.each do |attr, value|
        @rfi[attr] = value
      end

      if @rfi.save
        true
      else
        errors.relay(@rfi.errors)
        false
      end
    end

    def template
      template_exists?("forms/rfi/#{@brand.slug}") ? "forms/rfi/#{@brand.slug}" : "rfi"
    end
  end
end
