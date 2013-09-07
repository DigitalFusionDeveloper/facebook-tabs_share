class Su::UploadsController < Su::Controller
  before_filter :build_upload, :except => :index

  def new
    render :inline => '<%= render "form" %>', :layout => 'application'
  end

  def create
    if @upload.save
      redirect_to(:action => :show, :id => @upload.id)
    else
      render :inline => '<%= render "form" %>', :layout => 'application'
    end
  end

  def show
    redirect_to :action => 'edit'
  end

  def edit
    render :inline => '<%= render "form" %>', :layout => 'application'
  end

  def update
    if @upload.save
      redirect_to(:action => :edit, :id => @upload.id)
    else
      render :inline => '<%= render "form" %>', :layout => 'application'
    end
  end

  def index
    @uploads = Upload.all.order_by([:updated_at, :desc]).page(params[:page]).per(params[:per] || 5)
  end

protected
  def build_upload
    params[:upload] ||= {}

    @upload =
      if params[:upload][:cache]
        Upload.find(params[:upload][:cache])
      else
        if params[:id]
          Upload.find(params[:id])
        else
          Upload.new
        end
      end

    if params[:upload][:file]
      @upload.upload(params[:upload][:file])
    end
  end
end
