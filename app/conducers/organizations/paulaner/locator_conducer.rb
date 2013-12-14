module Organization::Paulaner
  class LocatorConducer < ::Dao::Conducer
    model_name :locator

    fattr :brand
    fattr :types
    fattr :locations

    def self.render!
      controller = Current.controller
      conducer = self

      controller.instance_eval do
        params = Map.for(controller.params)

        @locator = conducer.new(@brand, params[:locator])
        layout = @locator.layout

        if request.get?
          render :template => @locator.view_for(:locator), :layout => layout
          return
        end

        case params.get(:locator, :submit)
          when /search/i
            if @locator.search
              render :template => @locator.view_for(:search_results), :layout => layout
            else
              render :template => @locator.view_for(:locator), :layout => layout
            end
            return

          when /request/i
            if @locator.rfi
              message "Thanks for requesting #{ @brand.title.html_safe } at your location!", :class => :success
              redirect_to url_for(:action => :locator)
              #render :template => @locator.view_for(:rfi_thank_you), :layout => layout
            else
              render :template => @locator.view_for(:locator), :layout => layout
            end
            return

          else
            #@locator.form.messages.add params.inspect
            render :template => @locator.view_for(:locator), :layout => layout
        end
      end
    end

    def layout
      "organizations/paulaner/locator"
    end

    def view_for(which)
      "organizations/paulaner/locator/#{ which }"
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

      types = Coerce.list_of_strings(Array(params.get(:types)).select{|k,v| Coerce.boolean(v)}.to_a.map(&:first))

      [100, 1000, 10_000, 100_000].each do |miles|
        @locations = Location.find_all_by_lng_lat(@lng, @lat, :limit => 5, :miles => miles, :types => types)
        return true unless @locations.blank?
      end

      errors.add(:address, 'was not found')
      messages.add("Sorry, we didn't find any locations near you!")
      false
    end

    def rfi
      has_contact_info = false

      %w( email mobile_phone ).each do |input|
        if not params[input].blank?
          has_contact_info = true
        end
      end

      validates_as_email(:email, :allow_blank => true)
      validates_as_phone(:mobile_phone, :allow_blank => true)
      #validate_location

      return false unless valid?

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
        unless @rfi.email.blank?
          email = @rfi.email

          begin
            if Rails.env.production? or ENV['RAILS_EMAIL']
              #@rfi.fwd
            end
=begin
            if Rails.env.production? or ENV['EMAIL_SIGNUP']
              et = ExactTarget::Send.new
              er = et.send_email(@brand.slug, email)
            else
              Rails.logger.info "Would signup #{email}"
            end
=end
          rescue Object => e
            Rails.logger.error(e)
          end
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
      rescue Object => e
        Rails.logger.error(e)
        lat, lng = nil
      end

      unless lat and lng
        errors.add(:address, 'lookup failure')
        messages.add('Sorry, we cannot locate your address at this time.')
        return false
      end

      @lat, @lng = lat, lng
      return true
    end

    fattr(:search_form){ params[:submit].to_s.blank? or (params[:submit].to_s =~ /search/i) }
    fattr(:rfi_form){ !search_form? }
  end
end
