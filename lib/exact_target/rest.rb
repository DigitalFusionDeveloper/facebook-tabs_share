module ExactTarget
  class Rest
    class Config
      attr_accessor :client
      attr_accessor :client_id
      attr_accessor :client_secret
      attr_reader   :settings

      def initialize
        @client_id = App.sekrets[:exact_target][:client_id]
        @client_secret = App.sekrets[:exact_target][:client_secret]
      end

      def client=(client)
        @client = client
        @settings = Map.for(Settings.for(File.join(Rails.root, 'config/txt.yml'))[:exact_target][client])
      end
    end

    class << self
      attr_accessor :config
    end
    self.config ||= Config.new

    def self.configure
      yield config
      config
    end
  end
end
