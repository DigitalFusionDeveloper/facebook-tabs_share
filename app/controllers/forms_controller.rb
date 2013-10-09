class FormsController < ::ApplicationController
##
#
  layout 'forms'
  prepend_view_path 'app/views/brands'
  before_filter 'set_brand'

##
#
  def rfi
    @rfi = RFIConducer.for(@brand, @brand.rfis.new, params[:rfi])

    return if request.get?

    if @rfi.save
      @rfi.form.messages.success("Thanks #{ @rfi.email }!")
    else
=begin
      @rfi.errors.each do |key, list|
        title = key.split('.').last.titleize
        errors = list.join(', ')
        @rfi.form.messages.error("#{ title }: #{ errors }")
      end
=end
    end
  end

protected
##
#
  def set_brand
    @brand = Brand.find_by!(:slug => params[:brand])
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
      @rfi.brand = @brand

      unless attributes.email.to_s.split(/@/).size == 2
        errors.add(:email, 'is invalid')
      end

      if 'request-brand' == rfi_type
        if attributes.postal_code.blank?
          errors.add(:postal_code, 'is required')
        end
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
  end
end
