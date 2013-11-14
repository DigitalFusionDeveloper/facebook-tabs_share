module MapHelper
  def map_for_points(points,color = '0x00AEEF')
    labels = *('A'..'Z')
    markers = []

    points.each do |lat,lng|
      markers << "color:#{color}|label:#{labels.shift}|#{lat},#{lng}"
    end

    query = {
      :size    => "500x200",
      :scale   => 2,
      :sensor  => false,
      :style   => "saturation:-100"
    }.to_query
    "http://maps.googleapis.com/maps/api/staticmap?#{query}&#{format_markers(markers)}" 
  end

  private

  def format_markers(markers)
    markers.collect do |m|
      m.to_query(:markers)
    end.join('&')
  end      
end
