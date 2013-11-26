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
        validates_presence_of(:first_name)
        validates_presence_of(:last_name)
        validates_as_email(:email)
        validates_presence_of(:postal_code)
        
        if attributes.mobile_phone? and attributes.mobile_phone.length > 0
          validates_as_phone(:mobile_phone) 
        end

        return false unless valid?

        @brand.rfi_fields.each do |field|
          value = attributes[field]
          @rfi[field] = value
        end

        @rfi[:kind]         = 'default'
        @rfi[:brand]        = @brand.slug
        @rfi[:organization] = @brand.organization.try(:slug)

        if @rfi.save
          if Rails.env.production? or ENV['EMAIL_SIGNUP']
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

        unless params[:geo_location].blank?
          geo_location =
            begin
              GeoLocation.from_javascript(:address => params[:address], :data => params[:geo_location], :pinpoint => true)
            rescue
              errors.add(:address, 'is invalid')
              return false
            end

          if !geo_location.valid?
            if geo_location.status == 'OVER_QUERY_LIMIT'
              nil
            else
              errors.add(:address, 'is invalid')

              geo_location.errors.each do |key, list|
                message = Array(list).join(', ')
                errors.add(message)
              end
            end
          end
        else
          errors.add(:address, 'is invalid')
          return false
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
      fattr :types
      fattr :locations

      def PaulanerConducer.render!
        controller = Current.controller
        conducer = self

        controller.instance_eval do
          params = Map.for(controller.params)

          @locator = conducer.new(@brand, params[:locator])

          if request.get?
            render @locator.template_for(:locator)
            return
          end

          case params.get(:locator, :submit)
            when /search/i
              if @locator.search
                render @locator.template_for(:search_results)
              else
                render @locator.template_for(:locator)
              end
              return

            when /request/i
              if @locator.rfi
                render @locator.template_for(:rfi_thank_you)
              else
                render @locator.template_for(:locator)
              end
              return

            else
              @locator.form.messages.add params.inspect
              render @locator.template_for(:locator)
          end
        end
      end

      def template_for(which)
        case which.to_s
          when "locator"
            File.join(Rails.root.to_s, "app/views/organizations/paulaner/locator.html.erb")
          else
            File.join(Rails.root.to_s, "app/views/organizations/paulaner/#{ which }.html.erb")
        end
      end

      def label_for(string)
        case string.to_s.downcase
          when /draft/
            'Restaurant/Bar'
          when /package/
            'Store'
        end
      end

      def initialize(brand, params = {})
        @brand = brand
        @types = Location.where(brand: @brand.slug).types

        update_attributes(
          params
        )
      end

      def search
        return false unless validate_location

        types = Coerce.list_of_strings(params.get(:types).select{|k,v| Coerce.boolean(v)}.to_a.map(&:first))

        [100, 1000, 10_000, 100_000].each do |miles|
          @locations = Location.find_all_by_lng_lat(@lng, @lat, :limit => 5, :miles => miles, :types => types)
          return true unless @locations.blank?
        end

        errors.add(:address, 'was not found')
        messages.add("Sorry, we didn't find any locations near you!")
        false
      end

      def rfi
        validates_as_email(:email)
        validates_as_phone(:mobile_phone)
        validate_location

        return false unless valid?

        has_contact_info = false

        %w( email mobile_phone ).each do |input|
          if not params[input].blank?
            has_contact_info = true
          end
        end

        unless has_contact_info
          messages.add "Please provide an email or mobile phone number."
          errors.add :email, 'is blank'
          errors.add :mobile_phone, 'is blank'
          return false
        end

        @rfi = RFI.new

        @rfi[:kind]              = 'location'
        @rfi[:brand]             = @brand.slug
        @rfi[:organization]      = @brand.organization.try(:slug)

        @rfi[:address]           = params[:address].to_s.strip
        @rfi[:formatted_address] = params[:formatted_address].to_s.strip
        @rfi[:email]             = params[:email].to_s.strip
        @rfi[:mobile_phone]      = params[:mobile_phone].to_s.strip
        @rfi[:notes]             = params[:notes].to_s.strip
        @rfi[:lat]               = @lat.to_s.strip
        @rfi[:lng]               = @lng.to_s.strip

        if @rfi.save
          if Rails.env.production? or ENV['EMAIL_SIGNUP']
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

      def validate_location
        address = params[:address].to_s
        ll = params[:ll].to_s

        lat, lng = nil
        begin
          if !address.blank? and ll.blank?
            geo_location = GeoLocation.for(address)
            lat, lng = geo_location.lat, geo_location.lng
          end

          if !ll.blank?
            lat, lng = Coerce.list_of_floats(ll).first(2)
          end

          raise unless(lat && lng)
        rescue Object
          lat, lng = nil
        end

        unless lat and lng
          errors.add(:address, 'is missing')
          messages.add('Please supply an address')
          return false
        end

        @lat, @lng = lat, lng
        return true
      end

      fattr(:search_form){ params[:submit].to_s.blank? or (params[:submit].to_s =~ /search/i) }
      fattr(:rfi_form){ !search_form? }
    end
  end
end
