class JavascriptJob
#
  include App::Document

#
  field(:identifier, :type => String)

  field(:type, :type => String)
  field(:status, :type => String, :default => 'pending')
  field(:reserved_at, :type => Time)
  field(:completed_at, :type => Time)
  field(:code, :type => String)
  field(:result)

#
  index({:identifier => 1}, {:unique => true, :sparse => true})
  index({:status => 1})
  index({:reserved_at => 1})
  index({:completed_at => 1})

#
  validates_uniqueness_of(:identifier, :allow_blank => true)

#
  scope :pending, where(:status => 'pending')
  scope :complete, where(:status => 'complete')

#
  def JavascriptJob.next!(options = {})
    options.to_options!

    now = Time.now

    stale = options[:stale] || (now - 60)

    query =
      any_of(
        {:status => 'pending'},
        {:status.ne => 'complete', :reserved_at.lte => stale}
      )

    updates = {'$set' => {:status => 'running', :reserved_at => Time.now}}

    doc = query.find_and_modify(updates, :new => true)
  end

#
  Completed = Hash.new

  def JavascriptJob.completed!(type, &block)
    Completed[type.to_s.dowcase] = block
  end

  def completed!
    job = self

    block = Completed[type]
    Util.bcall(job, &block) if block

    job.status = 'complete'
    job.completed_at = Time.now.utc
    job.save!
  end

#
  def JavascriptJob.submit!(job)
    attributes = Map.for(job.is_a?(JavascriptJob) ? job.attributes : job)

    identifier = attributes[:identifier]

    if identifier
      begin
        where(:identifier => identifier).first || create!(attributes)
      rescue
        where(:identifier => identifier).first
      end
    else
      create!(attributes)
    end
  end

  def JavascriptJob.submit(*args)
    submit! rescue false
  end
end
