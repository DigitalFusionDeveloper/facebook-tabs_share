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
  
  class Brand
    def matches?(request)
      brand = request.path_parameters[:brand]
      ::Brand.exists?(brand)
    end
  end

  def Constraints.brand
    Brand.new # hehe
  end
end
