class Cache
  include Mongoid::Document

  Cache.default_collection_name = :cache
end
