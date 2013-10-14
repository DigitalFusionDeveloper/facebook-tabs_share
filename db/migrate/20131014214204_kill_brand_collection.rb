class KillBrandCollection < Mongoid::Migration
  def self.up
    c = 
      Class.new do
        include Mongoid::Document

        self.default_collection_name = 'brands'
      end

    c.collection.drop
  end

  def self.down
    nil
  end
end
