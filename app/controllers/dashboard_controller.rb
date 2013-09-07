class DashboardController < ApplicationController
  before_filter :require_current_user

  nav_for :main do |list|
    list.link(:dashboard, dashboard_path)
    list.link(:settings, url_for(:action => :settings))
  end

  def index
  end

  def settings
    @settings = Settings.new(Current.user, params[:settings])

    return if request.get?

    if @settings.save
      @settings.messages.each{|msg| message(*msg)}
      redirect_to(request.url, :status => 303)
    end
  end

protected

  class Settings < Dao::Conducer
    model_name :Settings

    def initialize(user, params = {})
      @user = user

      update_attributes(
        user.as_document
      )

      update_attributes(
        params
      )
    end

    validates_length_of(:name, :min => 3)
    validates_length_of(:password, :min => 3, :allow_blank => true)

    def save
      return unless valid?

      unless attributes[:name].blank?
        @user.name = attributes[:name]
      end

      unless attributes[:password].blank?
        message "Password updated.", :class => :success
        @user.password = attributes[:password]
      end

      if @user.save
        message "Settings saved", :class => :success
        true
      else
        errors.relay(@user.errors)
        false
      end
    end

    def message(*args)
      unless args.blank?
        messages.push(args)
      end
    end

    def messages
      @messages ||= []
    end
  end
end
