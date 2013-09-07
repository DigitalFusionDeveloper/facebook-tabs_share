class Su::JobsController < Su::Controller
  before_filter :build_job, :except => :index

  def index
    @jobs = Job.all.order_by([:updated_at, :desc]).page(params[:page]).per(params[:per] || 5)
  end

  def new
    render :inline => '<%= render "form" %>', :layout => 'application'
  end

  def create
    if @job.save
      redirect_to(:action => :show, :id => @job.id)
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
    if @job.save
      redirect_to(:action => :edit, :id => @job.id)
    else
      render :inline => '<%= render "form" %>', :layout => 'application'
    end
  end

protected
  def build_job
    params[:job] ||= {}

    @job =
      if params[:job][:cache]
        Job.find(params[:job][:cache])
      else
        if params[:id]
          Job.find(params[:id])
        else
          Job.new
        end
      end

    if params[:job][:file]
      @job.job(params[:job][:file])
    end
  end
end
