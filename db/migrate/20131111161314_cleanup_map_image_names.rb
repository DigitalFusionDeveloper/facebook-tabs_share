class CleanupMapImageNames < Mongoid::Migration
  def self.up
    Location.where(:map_image_id.ne => nil).each do |location|
      map_image = location.map_image

      basename = map_image.basename.force_encoding('utf-8')

      md5_basename = Location.md5_for(location.query_string) + '.png'

      if basename == md5_basename
        key      = basename.split('.').first
        basename = location.brand ? "#{ location.brand.slug }--#{ location.slug }.png" : "#{ location.slug }.png"

        map_image.update_attributes!(:key => key, :basename => basename)
        puts map_image.basename
      end
    end
  end

  def self.down
    Location.where(:map_image_id.ne => nil).each do |location|
      map_image = location.map_image

      md5_basename = Location.md5_for(location.query_string) + '.png'

      map_image.update_attributes!(:key => nil, :basename => md5_basename)
      puts map_image.basename
    end
  end
end
