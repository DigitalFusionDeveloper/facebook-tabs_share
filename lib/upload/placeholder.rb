class Upload
##
# placeholder support
#
  class Placeholder < ::String
    def Placeholder.route
      "/assets"
    end

    def Placeholder.root
      File.join(Rails.root, "app", "assets", "placeholders")
    end

    attr_accessor :url
    attr_accessor :path

    def initialize(placeholder = '', options = {})
      replace(placeholder.to_s)
      options.to_options!
      @url = options[:url] || default_url
      @path = options[:path] || default_path
    end

    def default_url
      return nil if blank?
      absolute? ? self : File.join(Placeholder.route, self)
    end

    def default_path
      return nil if blank?
      absolute? ? nil : File.join(Placeholder.root, self)
    end

    def basename
      File.basename(self)
    end

    def absolute?
      self =~ %r|\A([^:/]++:/)?/|
    end
  end

  def placeholder
    @placeholder ||= Placeholder.new
  end

  def placeholder=(placeholder)
    @placeholder = placeholder.is_a?(Placeholder) ? placeholder : Placeholder.new(placeholder)
  end
end
