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

    def layout_root
      File.join(Rails.root.to_s, 'app', 'views', 'layouts')
    end

    def view_root
      File.join(Rails.root.to_s, 'app', 'views')
    end

    def layout
      candidates = [
        "organizations/paulaner/locator/#{ @brand.slug }",
        "organizations/paulaner/locator"
      ]

      candidates.each do |candidate|
        if Dir.glob(File.join(layout_root, "#{ candidate }.*")).first
          return candidate
        end
      end

      nil
    end

    def view_for(which)
      candidates = [
        "organizations/paulaner/locator/#{ @brand.slug }/#{ which }",
        "organizations/paulaner/locator/#{ which }"
      ]

      candidates.each do |candidate|
        if Dir.glob(File.join(view_root, "#{ candidate }.*")).first
          return candidate
        end
      end

      nil
    end

    def label_for(string)
      case string.to_s.downcase
        when /draft/
          'Restaurants and Bars'
        when /package/
          'Stores'
      end
    end

    def singular_label_for(string)
      case string.to_s.downcase
        when /draft/
          'Restaurant/Bar'
        when /package/
          'Store'
      end
    end

    def search_criteria
      if params[:address].present?
        params[:address].to_s.strip
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
        @locations = Location.where(brand: @brand.slug).find_all_by_lng_lat(@lng, @lat, :limit => 5, :miles => miles, :types => types)
        return true unless @locations.blank?
      end

      errors.add(:address, 'was not found')
      messages.add("Sorry, we didn't find any locations near you!")
      false
    end

    def rfi
      @rfi = RFI.new

    # FIXME - this just barfs now because the form is ajax submit.  messages
    # are dealt with in the client...
    #
      #ok = %w( email mobile_phone ).map{|attr| params[attr].present?}.any?
      validates_as_email(:email, :allow_blank => true)
      validates_as_phone(:mobile_phone, :allow_blank => true)
      raise unless valid?

      @rfi[:kind]              = 'location'
      @rfi[:brand]             = @brand.slug
      @rfi[:organization]      = @brand.organization.try(:slug)

      @rfi[:email]             = params[:email].to_s.strip
      @rfi[:mobile_phone]      = params[:mobile_phone].to_s.strip
      @rfi[:notes]             = params[:notes].to_s.strip
      @rfi[:address]           = params[:address].to_s.strip
      @rfi[:formatted_address] = params[:formatted_address].to_s.strip
      @rfi[:lat]               = params[:lat].to_s.strip
      @rfi[:lng]               = params[:lng].to_s.strip
      @rfi[:ll]                = params[:ll].to_s.strip

      if @rfi.save
        begin
          if Rails.env.production? or ENV['RAILS_EMAIL']
          # TODO
            #@rfi.fwd
          end
        rescue Object => e
          Rails.logger.error(e)
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

      attributes[:lat] = @lat
      attributes[:lng] = @lng

      return true
    end

    fattr(:search_form){ params[:submit].to_s.blank? or (params[:submit].to_s =~ /search/i) }
    fattr(:rfi_form){ !search_form? }
  end
end
