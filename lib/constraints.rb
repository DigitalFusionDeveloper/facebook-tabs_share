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
end
