class ::RFI
  class PaulanerConducer < ::Dao::Conducer
    model_name :rfi

    fattr :brand
    fattr :rfi

    def self.render!
      controller = Current.controller
      conducer = self

      controller.instance_eval do
        rfi = RFI.new

        @rfi = conducer.new(@brand, rfi, params[:rfi])

        if params[:saved]
          Rails.logger.info('saved param is there.')
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
      if not attributes[:mobile_phone].blank?
        validates_as_phone(:mobile_phone)
      end

      validates_presence_of(:first_name)
      validates_presence_of(:last_name)
      validates_as_email(:email)
      validates_presence_of(:postal_code)

      return false unless valid?

      @brand.rfi_fields.each do |field|
        value = attributes[field]
        @rfi[field] = value
      end

      @rfi[:kind]         = 'default'
      @rfi[:brand]        = @brand.slug
      @rfi[:organization] = @brand.organization.try(:slug)

      if @rfi.save
        if Rails.env.production? or ENV['RAILS_EMAIL']
          et = ExactTarget::Send.new
          et.send_email(@brand.slug, email)
        else
          Rails.logger.info "Would signup #{email}"
        end
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
