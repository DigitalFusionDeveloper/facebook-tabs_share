###################################################################################
# tmpwatch support
###################################################################################

class Upload
  class << self
    def tmpwatch!(conditions = {})
      conditions.to_options!

      if conditions.empty?
        conditions.update(:updated_at.lt => 1.week.ago)
      end

      Upload.where(conditions.merge(:tmp => true)).each do |upload|
        upload.destroy unless upload.context_id
      end
    end
  end
end
