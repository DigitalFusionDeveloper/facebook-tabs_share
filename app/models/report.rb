class Report
  include App::Document

  field(:title, :type => String)
  field(:kind, :type => String)
  field(:config, :type => Hash, :default => proc{ Hash.new })

  GridFS = ::Mongoid::GridFS

  has_and_belongs_to_many(:attachments, :class_name => '::Report::GridFS::File', :dependent => :destroy, :inverse_of => nil)

  validates_presence_of(:title)
  validates_presence_of(:kind)
  validates_inclusion_of(:kind, :in => proc{ Report.kinds })

  before_validation do |report|
    if report.created_at.blank?
      report.created_at = Time.now.utc
    end

    if report.updated_at.blank?
      report.updated_at = Time.now.utc
    end

    if report.title.blank?
      report.title = Report.title_for(report)
    end
  end

  def Report.title_for(*args)
    args.flatten!
    args.compact!

    reports, labels = args.partition{|arg| arg.is_a?(Report)}

    created_at = reports.size > 0 ? reports.first.created_at : nil

    prefix = labels.map{|label| Slug.for(label)}.uniq

    prefix.delete('report')
    prefix.unshift('report') if prefix.blank?

    suffix = created_at.to_time.strftime('%Y%m%d%H%M%S') if created_at

    [prefix, suffix].compact.join('.')
  end

  def attach!(data, filename)
    io = data.respond_to?(:read) ? data : StringIO.new(data)
    grid_fs_file = GridFS.put(io, :filename => filename)
    attachments.push(grid_fs_file)
  end

  def Report.generator_for(*args, &block)
    Generator.for(*args, &block)
  end

  def Report.method_missing(method, *args, &block)
    super unless Generator.respond_to?(method)
    Generator.send(method, *args, &block)
  end

##
#
  class Generator < ::Dao::Conducer
  ##
  #
    def Generator.for(kind, params = {})
      kind = Generator.kind_for(kind)
      const = Generator.const_for(kind)

      if const_defined?(const)
        const_get(const).tap do |klass|
          instance = klass.new(kind, params || {})
          return instance
        end
      else
        raise NameError.new(kind.to_s)
      end
    end

    def Generator.generate(kind, params = {}, &block)
      Generator.for(kind, params).tap do |generator|
        generator.generate

        generator.report.attachments.each do |attachement|
          block.call(attachement) if block
        end
      end.report
    end

    def Generator.kinds
      @kinds ||= []
    end

    def Generator.kind_for(kind)
      (kind.is_a?(Class) ? kind.name : kind).to_s.split('::').last.underscore
    end

    def Generator.const_for(kind)
      kind = Generator.kind_for(kind)
      const = kind.camelize
    end

    def Generator.register(generator, &block)
      kind = Generator.kind_for(generator)
      kinds.push(kind)

      if block
        const = const_for(kind)
        remove_const(const) if const_defined?(const)
        klass = Class.new(Report::Generator)
        klass.class_eval(&block) if block
        const_set(const, klass)
      end

      kind
    ensure
      kinds.uniq!
    end

    def Generator.model_for(model_name)
      unless model_name.blank?
        model_name.to_s.constantize
      end
    end

    def Generator.timerange_for(starts_at, ends_at)
      unless starts_at.blank?
        inclusive_start_time = Coerce.time(starts_at).to_date.to_time(:utc)
      else
        inclusive_start_time = nil
      end

      unless ends_at.blank?
        exclusive_end_time = (Coerce.time(ends_at).to_date + 1).to_time(:utc)
      else
        exclusive_end_time = nil
      end

      [inclusive_start_time, exclusive_end_time]
    end

    def Generator.csv_for(fields, eachable)
      require 'csv' unless defined?(CSV)
      header = Coerce.list_of_strings(fields)

      CSV.generate do |csv|
        csv << header

        csv_rows_for(fields, eachable) do |row|
          csv << row
        end
      end
    end

    def Generator.csv_rows_for(fields, eachable, &block)
      rows = []
      fields = Coerce.list_of_strings(fields)

      eachable.each do |doc|
        row = fields.map{|field| doc.read_attribute(field)}
        block ? block.call(row) : rows.push(row)
      end
      
      block ? nil : rows
    end

    def Generator.json_for(rows)
      docs = rows.all.map(&:as_document)
      App.json_for(docs, :pretty => true)
    end

  ##
  #
    attr_accessor(:kind)
    attr_accessor(:report)

    def initialize(kind, params = {})
      @kind = Generator.kind_for(kind)
      @report = Report.new(:kind => @kind)

      if params.has_key?(form.name)
        update_attributes(
          params[form.name]
        )
      else
        update_attributes(
          params
        )
      end
    end
    
    def form_fields
      raise NotImplementedError
    end

    def generate
      raise NotImplementedError
    end
  end

##
#
  Dir.glob(Rails.root.join('lib/reports/generators/*.rb').to_s) do |file|
    ::Kernel.load(file)
  end
end
