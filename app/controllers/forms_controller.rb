class FormsController < ::ApplicationController
#
  layout 'forms'
  prepend_view_path 'app/views/brands'
  before_filter 'set_brand'

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

  def locator
    conducer =
      case @brand.organization.slug
        when 'paulaner'
          Locator::PaulanerConducer

        else
        raise IndexError.new(@brand.inspect)
      end

    conducer.render!
   end
#
  rpc(:geo_location) do |params|
    geo_location = GeoLocation.for(params[:address] || params[:geo_location])
    geo_location.as_document
  end

protected
#
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
          if Rails.env.production? or ENV['EMAIL_SIGNUP']
            et = ExactTarget::Send.new
            et.send_email(@brand.slug,email)
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

        fullAddress = 
          unless attributes[:address].blank?
            GeoLocation.locate(attributes[:address], :pinpoint => true)
          end

        if fullAddress and not fullAddress.valid?
          errors.add(:address, 'is invalid')

          fullAddress.errors.each do |key, list|
            message = Array(list).join(', ')
            errors.add(message)
          end
        end

        return false unless valid?

        @brand.rfi_fields.each do |field|
          value = attributes[field]
          @rfi[field] = value
        end

        @rfi[:brand] = @brand.slug
        @rfi[:organization] = @brand.organization.try(:slug)

        @rfi[:street_address] = fullAddress.street_address
        @rfi[:city] = fullAddress.city
        @rfi[:state] = fullAddress.state
        @rfi[:postal_code] = fullAddress.postal_code

        if @rfi.save
          if Rails.env.production? or ENV['ILOOP_OPTIN']
            begin
              il = ILoop::MFinity.new
              il.opt_in(@rfi[:mobile_phone])
            rescue
              nil
            end
          end

          if Rails.env.development?
            il = ILoop::MFinity.new
            il.opt_in("2075145450") # Sheena's number to test with.
          end

          recipients = Coerce.list_of_strings(@brand[:rfi_recipients])

          if Rails.env.development?
            Rails.logger.info "Mailer.rfi(#{ recipients.inspect })"
          end

          if Rails.stage and !Rails.stage.production?
            recipients = ['corey.inouye@mobilefusion.com', 'sheena.collins@mobilefusion.com']
          end

          unless recipients.blank?
            Job.submit(Mailer, :rfi, recipients)
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
        return ['Spring 2013', 'Fall 2013', 'Spring 2014', 'Fall 2014', 'Spring 2015', 'Fall 2015']
      end

      def options_for_hear_how
        return ['CCU Sponsored Event/conference', 'CCU Website', 'College Fair', 'Facebook', 'Friend/Family Member', 'High School Visit', 'KLOVE', 'Mail/E-mail', 'Other Website', 'WAYFM']
      end
    end
  end



  class ::Locator
    class PaulanerConducer < ::Dao::Conducer
      model_name :locator

      fattr :brand

      def PaulanerConducer.render!
        controller = Current.controller
        conducer = self
        controller.instance_eval do
          @locator = conducer.new(@brand)
          render @locator.form_template
        end
      end

      def initialize(brand, params = {})
        @brand = brand

        update_attributes(
          params
        )
      end

      def form_template
        File.join(Rails.root.to_s, 'app/views/brands', @brand.slug, 'locator_form.html.erb')
      end
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
