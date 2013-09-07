class Upload

  def Upload.route
    "/system/uploads"
  end

  module Routes
    Code = proc do
      match "#{ Upload.route }/:id(/:variant(/*path_info))" => "uploads#show", :via => :get, :format => false

      resource :uploads do
      end
    end

    def Routes.extend_object(object)
      super
    ensure
      object.instance_eval(&Code)
    end
  end

end
