module Admin
  class ReportsController < Controller
    def new
    #
      @kind = params[:kind]
      @step = params[:step].to_i

    #
      if @step == 0
        if @kind.blank?
          if Report::Generator.kinds.size == 1
            @kind = Report::Generator.kinds.first
            redirect_to(url_for(:action => :new, :kind => @kind, :step => 1))
            return
          end
        end

        if request.get?
          render(:template => 'admin/reports/new')
          return
        else
          redirect_to(url_for(:action => :new, :kind => @kind, :step => 1))
          return
        end
      end

    #
      if @step == 1
        @generator = Report.generator_for(@kind, params)
        return if request.get?

        if @generator.generate
          message("#{ h @kind.inspect } report generated.", :class => :success)
          redirect_to(url_for(:action => :index))
          return
        else
          render(:template => 'admin/reports/new')
          return
        end
      end

    #
      render(:template => 'admin/reports/new')
    end

    def create
      new
    end

    def index
      @reports = Report.order_by(:created_at => :desc).page(params[:page]).per(10)
    end

    def show
      @reports = Report.order_by(:created_at => :desc).where(:id => params[:id]).page(params[:page]).per(10)
      @report = @reports.first

      if @report.attachments.size == 1
        @attachment = @report.attachments.first

        plaintext =
          case @attachment.content_type
            when %r{\Atext/.*}, 'application/json'
              true
            else
              false
          end

        if plaintext
          render(:template => 'admin/reports/attachment')
        else
          grid_fs_render(@attachment, :attachment => false)
        end

        return
      else
        render(:template => 'admin/reports/index')
      end
    end

    include Mongoid::GridFS::Helper

    def attachment
      @report = Report.find(params[:report_id] || params[:id])
      @attachment = @report.attachments.find(params[:attachment_id] || params[:id])

      if params[:download]
        grid_fs_render(@attachment, :attachment => true)
      else
        grid_fs_render(@attachment)
      end
    end
  end
end
