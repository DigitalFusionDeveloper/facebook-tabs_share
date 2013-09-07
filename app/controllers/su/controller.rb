class Su::Controller < Admin::Controller
  before_filter :require_su_user
  layout :layout_for_request

protected
  def initialize_layout
    super

    @layout.nav_for(:main) do |list|
      list.link(:su, su_path)
      list.link(:logs, su_path(:action => :logs))
      list.link(:jobs, su_path(:action => :jobs))
      list.link(:test, su_path(:action => :test))
      #list.link(:uploads, su_path(:action => :uploads))
      #list.link(:reports, su_path(:action => :reports))
    end
  end
end
