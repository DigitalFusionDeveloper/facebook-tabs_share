module App
  module Document
    code_for :timestamps do
      include ::Mongoid::Timestamps
    end

    def timestamps
      Map[:created_at, created_at, :updated_at, updated_at]
    end
  end
end
