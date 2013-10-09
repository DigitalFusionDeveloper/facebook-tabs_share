module Constraints
  class Admin
    def matches?(request)
      if request.session['real_user']
        begin
          User.find(request.session['real_user'])
          return true
        rescue
          return false
        end
      end
      return false
    end
  end

  def Constraints.admin
    Admin.new
  end
  
  class Forms
    ALLOWED_TYPES = %w[rfi locator]
    def matches?(request)
      ALLOWED_TYPES.include?(request.path_parameters[:type])
    end
  end

  def Constraints.forms
    Forms.new
  end
end
