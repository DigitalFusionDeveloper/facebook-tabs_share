Report.register(:model) do

  def form_fields
    dl_{
      [
        {
          :label   => [:config, :name, :content => 'Model Name'],
          :element => [:select, [:config, :name], :from => model_names]
        },

        {
          :label   => [:config, :format, :content => 'Format'],
          :element => [:select, [:config, :format], :from => %w( json csv )]
        },

        {
          :label   => [:config, :starts_at, :content => 'Begins At'],
          :element => [:input, [:config, :starts_at], :placeholder => 'any date such as "last monday" or 1999-12-31']
        },

        {
          :label   => [:config, :ends_at, :content => 'Ends At'],
          :element => [:input, [:config, :ends_at], :placeholder => 'any date such as "today" or 1999-12-31']
        },
      ].each do |config|
        tagz << form.label(*config[:label])

        tagz << form.send(*config[:element])
      end
    }
  end

  def model_names
    (App::Document.models - [Report]).map(&:name).sort
  end

  def generate
    generator = self
    attributes[:config] ||= {}

    config = Map.for(generator.attributes.config)
    model  = Report.model_for(config[:name])

    @report        = Report.new
    @report.title  = Report.title_for(@report, generator.kind, model.name)
    @report.kind   = generator.kind
    @report.config = generator.attributes.config

    query = model.all.order_by(:created_at => :desc)

    report_fields =
      Coerce.list_of_strings(
        if model.respond_to?(:report_fields)
          model.report_fields
        else
          model.fields.keys
        end
      )

    if report_fields.include?('created_at')
      inclusive_start_time, exclusive_end_time = Report.timerange_for(config[:starts_at], config[:ends_at])

      if inclusive_start_time
        query = query.where(:created_at.gte => inclusive_start_time)
      end

      if exclusive_end_time
        query = query.where(:created_at.lt => exclusive_end_time)
      end
    end

    case config[:format].to_s
      when 'csv'
        csv = Report.csv_for(report_fields, query)
        @report.attach!(csv, "#{ @report.title }.csv")

      when 'json'
        json = Report.json_for(query)
        @report.attach!(json, "#{ @report.title }.json")

      else
        raise ArgumentError, config[:format].to_s
    end

    return(
      if @report.save
        true
      else
        errors.relay(@report.errors)
        false
      end
    )
  end

end
