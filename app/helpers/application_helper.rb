require 'handlebars'

module ApplicationHelper
  include Tagz.globally

  def solid(*args)
    args.join(' ').solid
  end

  def css_for(hash = {})
    hash.to_css
  end
  alias_method(:css, :css_for)

  def style_for(hash = {})
    hash.map{|kv| kv.join(':')}.join(';') + ';'
  end
  alias_method(:style, :style_for)

  def gzipped_asset_path(*args)
    if Rails.env.production?
      asset_path(*args) + '.gz'
    else
      asset_path(*args)
    end
  end

  def gzipped_stylesheet_link_tag(*args)
    options = args.extract_options!.to_options!

    args.push(:ext => :css)
    path = gzipped_asset_path(*args)

    options[:href] ||= path
    options[:media] ||= 'all'
    options[:rel] ||= 'stylesheet'
    options[:type] ||= 'text/css'

    link_(options){}
  end

  def gzipped_javascript_include_tag(*args)
    options = args.extract_options!.to_options!

    args.push(:ext => :js)
    path = gzipped_asset_path(*args)

    options[:src] ||= path
    options[:type] ||= 'text/javascript'

    script_(options) + _script
  end

  def tel_to(number)
    link_to number, "tel:#{ number }"
  end

  def default_content_for(name, &block)
    if !content_for?(name)
      content_for("default_#{ name }", &block)
      content_for("default_#{ name }")
    else
      content_for(name)
    end
  end

  def content_for_script(&block)
    default_content_for(:script, &block)
  end

  def content_for_style(&block)
    default_content_for(:style, &block)
  end

  def json_for(object)
    raw(App.json_for(object))
  end
  alias_method('j', 'json_for')
  alias_method('js', 'json_for')

  def jsonp(*args, &block)
    name = args.shift || 'jsonp'
    callback = params[:callback] || params[:cb] || 'callback'
    content = capture(&block)
    unless callback
      concat(content)
    else
      concat("#{ callback }(#{ content.to_json })")
    end
  end

# generic form helps handling AR objects and other shiznit
#
  def form(*args, &block)
    options = args.extract_options!.to_options!

    model = args.first

    if model.respond_to?(:persisted)
      model = args.first

      options[:html] = (options[:html] || {}).merge!(form_attrs!(options))

      if options[:url].blank?
        options[:url] = url_for(:action => (model.persisted? ? :update : :create))
      end

      if model.respond_to?(:form_builder)
        options[:builder] = model.form_builder
      end

      form_for(model, options, &block)
    else
      if args.empty?
        action = options.delete(:action) || request.fullpath
        args.unshift(action)
      end

      options.merge!(form_attrs(options))

      args.push(options)

      form_tag(*args, &block)
    end
  end
 

# merge default with specified form options.  recognizes some special form
# classes like 'small' 'medium', etc...
#
  def form_attrs!(*args)
    options = args.extract_options!.to_options!

    form_attrs = {}

    form_attrs[:class] =
      [args, options.delete(:class)].join(' ').scan(%r/[^\s]+/).push(' app ').uniq.join(' ')

    form_attrs[:enctype] =
      options.delete(:enctype) || "multipart/form-data"

    if options[:method]
      form_attrs[:method] = options.delete(:method)
    end

    form_attrs
  end

  def form_attrs(options = {})
    form_attrs!(options.dup)
  end


# hash in -> css style definition out
#
  def css_for(hash)
    unless hash.blank?
      css = []

      hash.each do |selector, attributes|
        unless attributes.blank?
          guts = []
          attributes.each do |key, val|
            guts << "#{ key } : #{ val };"
          end
          unless guts.blank?
            css << "#{ selector } { #{ guts.join(' ') } }"
          end
        end
      end

      unless css.empty?
        css.join("\n")
      end
    end
  end

# keeps paragraphs and linebreaks
#
  def simple_format(string, options = {})
    options.to_options!

    options[:paragraphs] = options.delete(:p) if options.has_key?(:p)
    options[:paragraphs] = true unless options.has_key?(:paragraphs)

    content = string.to_s.strip
    content.gsub!(%r/([\ ]{2,})/){'&nbsp;' * $1.size}  # keep spaces

    return content unless(content =~ %r/\n\r/)

    if options[:paragraphs]
      content.gsub!(/\r\n?/, "\n")                     # \r\n and \r -> \n
      content.gsub!(/\n\n+/, "</p>\n\n<p>")            # 2+ newline  -> paragraph
      content.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />')  # 1 newline   -> br
      raw("<p>#{ content }</p>")
    else
      content.gsub!(/\r\n?/, "\n")                     # \r\n and \r -> \n
      content.squeeze!("\n")
      content.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />')  # 1 newline   -> br
      raw(content)
    end
  end
  alias_method('s', 'simple_format')

# keeps paragraphs, linebreaks, internal spaces.  sanitizes js/html.  and hyperlinks linky looking stuff
#
  def clean_format(string, options = {})
    options.to_options!
    content = sanitize(string.to_s)
    content = auto_link(content, :all, options.slice(:target))
    content = simple_format(content, options)
  end
  alias_method('c', 'clean_format')

# markdown
#
  def markdown(*args, &block)
    options = args.extract_options!.to_options!
    string = (block ? capture(&block) : args.shift).to_s
    string.gsub!(/\A(^\s*$)+\n/, '')
    string.gsub!(/(^\s*$)+\Z/, '')
    string = Util.unindent(string)
    Util.markdown.render(string).html_safe
  end
  alias_method('m', 'markdown')

# unicode chars
#
  def left_quote()
    '&#8220;'
  end
  def right_quote()
    '&#8221;'
  end
  def small_right_pointing_triangle
    '&#x25B8;'
  end
  def right_pointing_triangle
    '&#x25B6;'
  end
  def space
    '&nbsp;'
  end

# hms(61) #=> 00:01:01
#
  def hms(seconds)
    Util.hms(seconds)
  end

# unwrap("<div> <span> foobar </span> </div>", :tags => %w( div span)) #=> "foobar"
#
  def unwrap(content, options = {})
    unwrap!("#{ content }", options)
  end

  def unwrap!(content, options = {})
    content = content.to_s
    options.to_options!
    tags = [options[:tag], options[:tags]].flatten.compact
    tags.each do |tag|
      content.sub!(%r|^\s*<#{ tag }[^>]+>|, '')
      content.sub!(%r|</#{ tag }>\s*$|, '')
    end
    content
  end

# a unique domid
#
  def domid
    App.domid
  end

# simple error message generator
#
  def errors_for(errors)
    ::Errors2Html.to_html(errors)
  end

  def icon(which)
    which = which.to_s
    which = "icon-#{ which }" unless which =~ %r/^icon-/iomx
    raw("<i class='%s'></i>" % which)
  end

end
