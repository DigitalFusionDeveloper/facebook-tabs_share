class LayoutConducer < Dao::Conducer
  def initialize
    update_attributes(
      :title => App.title
    )

    update_attributes(
      :nav => Map.new
    )
  end

  def nav_for(*args, &block)
    name = args.first.to_s

    if block
      nav[name] = Nav.for(*args, &block).for(controller)
    end

    nav[name] || []
  end
end
