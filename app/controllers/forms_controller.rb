class FormsController < ::ApplicationController
#
  layout 'forms'
  prepend_view_path 'app/views/brands'
  before_filter 'set_brand'

#

  def rfi
    conducer =
      case @brand.organization.slug
        when 'paulaner'
          RFI::PaulanerConducer

        else
          raise IndexError.new(@brand.inspect)
      end

    conducer.render!
  end

protected
#
  def set_brand
    @brand = Brand.for(:slug => params[:brand])

    if @brand.nil?
      render(:text => "brand #{ params[:brand].inspect } not found", :status => 404)
    end
  end

  class ::RFI
    class PaulanerConducer < ::Dao::Conducer
      model_name :rfi

      fattr :brand
      fattr :rfi

      def PaulanerConducer.render!
        controller = Current.controller
        conducer = self

        controller.instance_eval do
          rfi = RFI.new

          @rfi = conducer.new(@brand, rfi, params[:rfi])

          if params[:saved]
            render @rfi.thank_you_template
            return
          end

          if request.get?
            render @rfi.form_template
            return
          end

          if @rfi.save
            redirect_to url_for(:saved => :true)
          else
            render @rfi.form_template
          end
        end
      end

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
        validates_presence_of(:first_name)
        validates_presence_of(:last_name)
        validates_as_email(:email)
        validates_as_phone(:mobile_phone)
        validates_presence_of(:postal_code)

        return false unless valid?

        @brand.rfi_fields.each do |field|
          value = attributes[field]
          @rfi[field] = value
        end

        @rfi[:brand] = @brand.slug
        @rfi[:organization] = @brand.organization.try(:slug)

        if @rfi.save
          return true
        else
          @errors.relay(@rfi.errors)
          return false
        end
      end

      def form_template
        File.join(Rails.root.to_s, 'app/views/brands', @brand.slug, 'rfi_form.html.erb')
      end

      def thank_you_template
        File.join(Rails.root.to_s, 'app/views/brands', @brand.slug, 'rfi_thank_you.html.erb')
      end
    end
  end

  class PaulanerRFIConducer < ::Dao::Conducer
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


=begin
  def normalize!
    normalize_name!
  end

  def normalize_name!
    if self.name.blank?
      name = [first_name, last_name].join(' ')
      self.name = name unless name.blank?
    end

    if self.name.blank?
      name = email.to_s.split(/@/).first.to_s.scan(/\w+/).map(&:titleize).join(' ')
      self.name = name unless name.blank?
    end

    unless self.name.blank?
      parts = self.name.scan(/\w+/)
      first_name = parts.shift
      last_name = parts.pop
      if self.first_name.blank?
        self.first_name = first_name unless first_name.blank?
      end
      if self.last_name.blank?
        self.last_name = last_name unless last_name.blank?
      end
    end
  end
=end
