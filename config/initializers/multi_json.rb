MultiJson.use(:yajl)

module MultiJson
  class << self
    def engine
      MultiJson.adapter
    end

    def engine=(*args)
      MultiJson.use(*args)
    end

    def encode(*args)
      MultiJson.dump(*args)
    end

    def decode(*args)
      MultiJson.load(*args)
    end
  end
end

