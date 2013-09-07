module Admin
  class UploadsController < Admin::Controller
    def index
      @uploads = Upload.order_by(:created_at => :desc).page(params[:page]).per(10)
    end

  protected
    class Conducer < App::Conducer
      def initialize(upload, params = {})
        update_attributes(
          upload.as_document
        )

        update_attributes(
          params
        )
      end
    end
  end
end
