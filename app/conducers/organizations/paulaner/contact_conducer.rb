module Organization::Paulaner
  class ContactConducer < ::Dao::Conducer
    model_name :contact

    fattr :brand
    fattr :messages
    fattr :rfi

    def self.render!
      controller = Current.controller
      conducer = self

      controller.instance_eval do
        params = Map.for(controller.params)

        rfi = RFI.new
        @rfi = conducer.new(@brand, rfi, params[:contact])
        layout = @rfi.layout

        @rfi.candidates.each do |candidate|
          append_view_path File.join('app', 'views', candidate)
        end


        if request.get?
          render :template => @rfi.view_for(:contact), :layout => layout
          return
        end

        case params.get(:contact, :submit)
          when /submit/i
            if @rfi.save
              render :template => @rfi.view_for(:thanks), :layout => layout
            else
              render :template => @rfi.view_for(:contact), :layout => layout
            end
          else
            render :template => @rfi.view_for(:contact), :layout => layout
        end
      end
    end

    def layout_root
      File.join(Rails.root.to_s, 'app', 'views', 'layouts')
    end

    def view_root
      File.join(Rails.root.to_s, 'app', 'views')
    end

    def candidates
      [
       "organizations/paulaner/contact/#{ @brand.slug }",
       "organizations/paulaner/contact"
      ]
    end
    
    def layout
      candidates.each do |candidate|
        if Dir.glob(File.join(layout_root, "#{ candidate }.*")).first
          return candidate
        end
      end

      nil
    end

    def view_for(which)
      candidates.each do |candidate|
        if Dir.glob(File.join(view_root, "#{ candidate }/#{ which }.*")).first
          return "#{ candidate }/#{ which }"
        end
      end

      nil
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
  end
end
