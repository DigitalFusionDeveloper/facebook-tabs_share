class JavascriptJob
  include App::Document

  field(:type, :type => String)
  field(:status, :type => String, :default => 'pending')
  field(:reserved_at, :type => Time)
  field(:completed_at, :type => Time)
  field(:code, :type => String)
  field(:result)

  index({:status => 1})
  index({:reserved_at => 1})
  index({:completed_at => 1})

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

  Completed = Hash.new

  def JavascriptJob.completed!(type, &block)
    Completed[type.to_s.dowcase] = block
  end

  def completed!
    block = Completed[type]
    block.call(self) if block
    job.status = 'complete'
    job.completed_at = Time.now.utc
    job.save!
  end
end
