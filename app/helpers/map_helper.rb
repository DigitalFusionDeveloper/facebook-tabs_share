module MapHelper
  def map_for_points(points,options = {})
    labels = *('A'..'Z')
    markers = []

    color = options.delete(:color) || '0x00AEEF'

    points.each do |lat,lng|
      markers << "color:#{color}|label:#{labels.shift}|#{lat},#{lng}"
    end

    query = {
      :size    => "500x200",
      :scale   => 2,
      :sensor  => false,
      :style   => "saturation:-100"
    }.merge(options).to_query
    "//maps.googleapis.com/maps/api/staticmap?#{query}&#{format_markers(markers)}" 
  end

  private

  def format_markers(markers)
    markers.collect do |m|
      m.to_query(:markers)
    end.join('&')
  end      
end
