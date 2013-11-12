class Admin::Controller < ApplicationController
  before_filter :require_admin_user
  layout :layout_for_request

protected
  def initialize_layout
    super

    @layout.nav_for(:main) do |nav|
      nav.link(:Users   , admin_users_path, :default => true)
      nav.link(:Locations , admin_locations_path)
      nav.link(:Uploads , admin_uploads_path)
      nav.link(:Reports , admin_reports_path)
    end
  end

  def default_layout
    'admin'
  end
end
