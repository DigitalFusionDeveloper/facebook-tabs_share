#
# Template('flash-list-item',  {message:'foobar'} )
#
# or
#
# Template('flash-list-item').render({message:'foobar'})
#
# or
#
# template = Template('flash-list-item')
# template.render({message:'foobar'})
#

class Template
  def Template.load_file(file, options = {})
    compile(file)
  end

  def Template.compile(file)
    html = render_view(file, {})
    doc = Nokogiri::HTML(html)
    doc.search('script').each do |script|
      name = script['name']
      unless name.blank?
        content = script.content
        template = new(content, options = {})
        cache[name] ||= template
      end
    end
  end

  def Template.precompile(name, template)
    tmpl = Template.cache[name] || Template.new(template)
    tmpl.to_precompiled_js
  end

  def Template.cache
    @cache ||= Map.new
  end

  def Template.context
    @context ||= Handlebars::Context.new
  end

  def Template.handlebars
    context.handlebars
  end

  def Template.render_view(file, params)
    view = ActionView::Base.new(ActionController::Base.view_paths, {})

    class << view
      include ActionView::Helpers, ::Template::Helpers, Tagz
    end

    unless file.starts_with?('/')
      file = File.join(Rails.root, file)
    end

    dirname, basename = File.split(file)
    base, extension = basename.split('.', 2)
    prefix = File.join(dirname, base)

    view.render(:file => prefix, :locals => params)
  end

  def initialize(template, options = {})
    @template = template
  end

  def compile
    @hbs ||= Template.context.compile(source)
  end

  def to_precompiled_js
    @js ||= Template.handlebars.precompile(source)
  end

  def render(data = {})
    compile unless compiled?
    @hbs.call(data).strip
  end

  def source
    @template
  end

  def compiled?
    !!@hbs
  end

  module Helpers
    def template_for(*args, &block)
      name = args.first
      options = args.extract_options!.to_options!

      options[:type] ||= "text/x-handlebars-template"
      options[:class] ||= "template"
      options[:name] ||= name

      tmpl_src = capture(&block)

      tmpl = ::Template.cache[name] ||= ::Template.new(tmpl_src)

      if Rails.env.development?
        script_(options) do
          tmpl.source.html_safe
        end
      else
        js = tmpl.to_precompiled_js
        script_ type: 'text/javascript' do
          str = <<-JS
            Template.cache['#{name}'] = {
              compiled: Handlebars.template(#{js}),
              render: function(context, options) {
                options = options || {};
                return this.compiled(context, options);
              }
            };
          JS
          str.gsub(/\s+/, ' ').html_safe
        end
      end
    end
  end
end

ActionView::Base.send :include, Template::Helpers

def Template(name, *args, &block)
  template = Template.cache[name.to_s]
  args.size==0 && !block ? template : template.render(*args, &block)
end

%w(

  app/views/shared/_templates.html.erb

  app/views/shared/templates.html.erb

  app/views/_templates.html.erb

  app/views/templates.html.erb

).each do |basename|
  file = File.join(Rails.root, basename)
  Template.load_file(file) if test(?s, file)
end



if $0 == __FILE__
  unless defined?(Nokogiri)
    require 'rubygems'
    require 'nokogiri'
    require 'handlebars'
    require 'map'
  end

  file = ARGV.shift
  Template.load_file(file)

  keys = Template.cache.keys
  t = Template.cache[keys.first]
  p t
  puts
  puts t.render('message' => 'foobar')
end


