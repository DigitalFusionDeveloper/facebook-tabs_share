class ::RFI
  class CCUConducer < ::Dao::Conducer
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
      validates_presence_of(:term)
      validates_presence_of(:referral)
      validates_presence_of(:address)

      geo_location = nil

      unless params[:geo_location].blank?
        geo_location =
          begin
            GeoLocation.from_javascript(:address => params[:address], :data => params[:geo_location], :pinpoint => true)
          rescue
            nil
          end
      end

      return false unless valid?

      @brand.rfi_fields.each do |field|
        value = attributes[field]
        @rfi[field] = value
      end

      @rfi[:brand] = @brand.slug
      @rfi[:organization] = @brand.organization.try(:slug)

      @rfi[:address]        = geo_location.try(:address)
      @rfi[:street_address] = geo_location.try(:street_address)
      @rfi[:city]           = geo_location.try(:city)
      @rfi[:state]          = geo_location.try(:state)
      @rfi[:postal_code]    = geo_location.try(:postal_code)

      if @rfi.save
        ExactTarget::Rest.configure do |config|
          config.client = :ccu
        end
        if Rails.env.production? or ENV['ILOOP_OPTIN']
          begin
            q = ExactTarget::QueueMO.new
            q.opt_in(@rfi[:mobile_phone])
          rescue
            nil
          end
        end

        if Rails.env.development?
          # q = ExactTarget::QueueMO.new
          # q.opt_in("2075145450") # Sheena's number to test with.
        end

        recipients = Coerce.list_of_strings(@brand[:rfi_recipients])

        if Rails.env.development?
          Rails.logger.info "Mailer.rfi(#{ recipients.inspect })"
        end

        if Rails.stage and !Rails.stage.production?
          recipients = ['corey.inouye@mobilefusion.com', 'sheena.collins@mobilefusion.com']
        end

        unless recipients.blank?
          Job.submit(Mailer, :rfi, @rfi.id, recipients)
        end

      # TODO - iLoop and mail addys here...
=begin

        if Rails.env.production? or ENV['EMAIL_SIGNUP']
          et = ExactTarget::Send.new
          et.send_email(@brand.slug,email)
        else
          Rails.logger.info "Would signup #{email}"
        end
=end
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

    def options_for_term
      return ['Fall 2014', 'Spring 2015', 'Fall 2015', 'Spring 2016', 'Fall 2016', 'Spring 2017',]
    end

    def options_for_hear_how
      return ['CCU Sponsored Event/conference', 'CCU Website', 'College Fair', 'Facebook', 'Friend/Family Member', 'High School Visit', 'KLOVE', 'Mail/E-mail', 'Other Website', 'WAYFM']
    end
  end

  CcuConducer = CCUConducer
end
