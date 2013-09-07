module MarkdownTemplateHandler
  def self.erb
    @erb ||= ActionView::Template.registered_template_handler(:erb)
  end

  def self.markdown(*args, &block)
    Util.markdown(*args, &block)
  end

  def self.call(template)
    template = erb.call(template)
    "MarkdownTemplateHandler.markdown.render(begin;#{ template };end).html_safe"
  end
end

ActionView::Template.register_template_handler(:md, MarkdownTemplateHandler)
ActionView::Template.register_template_handler(:markdown, MarkdownTemplateHandler)
