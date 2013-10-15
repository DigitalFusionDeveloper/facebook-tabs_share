module Util
  def bcall(*args, &block)
    call(block, :call, *args)
  end

  def call(object, method, *args, &block)
    args = args_for_arity(args, object.method(method).arity)
    object.send(method, *args, &block)
  end

  def args_for_arity(args, arity)
    arity = Integer(arity.respond_to?(:arity) ? arity.arity : arity)
    arity < 0 ? args.dup : args.slice(0, arity)
  end

  def slowhash(string)
    BCrypt::Password.create(string.to_s).to_s
  end

  def load_config_yml(path)
    YAML::load(ERB.new((IO.read(path))).result)
  end

  def parse_seconds(time)
    return time unless time
    return time if time.is_a?(Numeric)

    parts = time.to_s.gsub(/[^\d:]/,'').split(/:/)
    seconds = parts.pop
    minutes = parts.pop
    hours = parts.pop

    seconds = Float(seconds).to_i
    seconds += Float(minutes).to_i * 60 if minutes
    seconds += Float(hours).to_i * 60 * 60 if hours

    seconds
  end

  def hours_minutes_seconds(seconds)
    return unless seconds
    seconds = Float(seconds).to_i
    hours, seconds = seconds.divmod(3600)
    minutes, seconds = seconds.divmod(60)
    [hours.to_i, minutes.to_s, seconds]
  end

  def hms(seconds)
    return unless seconds
    "%02d:%02d:%02d" % hours_minutes_seconds(seconds)
  end

  def nearest_ceiling(i, unit = 10)
    Integer(i + unit) / unit * unit
  end

  def nearest_floor(i, unit = 10)
    Integer(i - unit) / unit * unit
  end

  def paths_for(*args)
    path = args.flatten.compact.join('/')
    path.gsub!(%r|[.]+/|, '/')
    path.squeeze!('/')
    path.sub!(%r|^/|, '')
    path.sub!(%r|/$|, '')
    paths = path.split('/')
  end

  def absolute_path_for(*args)
    path = ('/' + paths_for(*args).join('/')).squeeze('/')
    path unless path.blank?
  end

  def relative_path_for(*args)
    path = absolute_path_for(*args).sub(%r{^/+}, '')
    path unless path.blank?
  end
    
  def normalize_path(arg, *args)
    absolute_path_for(arg, *args)
  end

  def normalize_email(email)
    email.to_s.downcase.scan(/[^\s]/).join if email
  end

## pattern support
#
  Patterns =
    Map[
      :id,
        %r/^ [0-9]+ $/iox,

      :objectid,
        %r/\A [0-9a-z]{24} \Z/iox,

      :uuid,
        %r/^ [0-9a-zA-Z]{8} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{12} $/iox,

      :email,
        %r/^[^@\s]+@[^@\s]+$/iox
    ]

  Patterns[:object_id] = Patterns[:objectid]

  def patterns
    Patterns
  end

  Constraints =
    Map[
      :uuid,
        %r/ [0-9a-zA-Z]{8} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{12} /iox,

      :token,
        %r/ [0-9a-zA-Z]{8} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{4} - [0-9a-zA-Z]{12} /iox
    ]

  def constraints
    Constraints
  end

  def uuid_pattern
    patterns.uuid
  end

  def id_pattern
    patterns.id
  end

  def email_pattern
    patterns.email
  end

  def id_or_uuid?(*args)
    args.flatten.compact.all?{|arg| id?(arg) or uuid?(arg)} 
  end

  def uuid_or_id?(*args)
    args.flatten.compact.all?{|arg| uuid?(arg) or id?(arg)} 
  end

  def uuid?(*args)
    args.flatten.compact.all?{|arg| arg.to_s =~ patterns.uuid}
  end

  def id?(*args)
    args.flatten.compact.all?{|arg| arg.to_s =~ patterns.id}
  end

## html processing
#     
  class SyntaxHighlighting < Redcarpet::Render::HTML
    def block_code(code, language)
      language = 'ruby' if language.to_s.strip.empty?
      Pygments.highlight(code, :lexer => language, :options => {:encoding => 'utf-8'})
    end
  end
  
  def markdown(*args, &block)
    @markdown ||=
      Redcarpet::Markdown.new(
        SyntaxHighlighting,
    
        :no_intra_emphasis   => true,
        :tables              => true,
        :fenced_code_blocks  => true,
        :autolink            => true,
        :strikethrough       => true,
        :lax_html_blocks     => true,
        :space_after_headers => true,
        :superscript         => true
      )

    if args.empty? and block.nil?
      @markdown
    else
      source = args.join
      return nil if source.blank?
      @markdown.render(source, &block).strip.sub(/\A<p>/,'').sub(/<\/p>\Z/,'').html_safe
    end
  end

##
#
  def erb(source, binding = TOPLEVEL_BINDING)
    return nil if source.blank?
    ERB.new(source).result(binding).html_safe
  end

  def tidy(html)
    ::Nokogiri::HTML::DocumentFragment.parse(html.to_s).to_html rescue html.to_s
  end

  # via: http://emmanueloga.wordpress.com/2009/09/29/pretty-printing-xhtml-with-nokogiri-and-xslt/
  #
  def tidy_fragment(html)
    begin
      xsl = <<-__
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output method="xml" encoding="ISO-8859-1"/>
        <xsl:param name="indent-increment" select="'   '"/>

        <xsl:template name="newline">
          <xsl:text disable-output-escaping="yes">
      </xsl:text>
        </xsl:template>

        <xsl:template match="comment() | processing-instruction()">
          <xsl:param name="indent" select="''"/>
          <xsl:call-template name="newline"/>
          <xsl:value-of select="$indent"/>
          <xsl:copy />
        </xsl:template>

        <xsl:template match="text()">
          <xsl:param name="indent" select="''"/>
          <xsl:call-template name="newline"/>
          <xsl:value-of select="$indent"/>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:template>

        <xsl:template match="text()[normalize-space(.)='']"/>

        <xsl:template match="*">
          <xsl:param name="indent" select="''"/>
          <xsl:call-template name="newline"/>
          <xsl:value-of select="$indent"/>
            <xsl:choose>
             <xsl:when test="count(child::*) > 0">
              <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates select="*|text()">
                 <xsl:with-param name="indent" select="concat ($indent, $indent-increment)"/>
               </xsl:apply-templates>
               <xsl:call-template name="newline"/>
               <xsl:value-of select="$indent"/>
              </xsl:copy>
             </xsl:when>
             <xsl:otherwise>
              <xsl:copy-of select="."/>
             </xsl:otherwise>
           </xsl:choose>
        </xsl:template>
      </xsl:stylesheet>
      __

      xslt = Nokogiri::XSLT(xsl)
      doc = Nokogiri::HTML(html)
      formatted = xslt.apply_to(doc)
      tidy = formatted.split( Regexp.union(Regexp.escape('<body>'), Regexp.escape('</body>')) )[1]
      Util.unindent(tidy).gsub(/\n/, "\n\n").strip
    rescue Object => e
      html
    end
  end

  def excerpt(html, *args)
    if args.empty?
      AutoExcerpt.new(html.to_s, {:strip_html => false, :paragraphs => 1}).html_safe
    else
      AutoExcerpt.new(html.to_s, *args).html_safe
    end
  end

  def html2text(html)
    Nokogiri::HTML(html.to_s).inner_text
  end

##
#
  def unindent(string)
    string.unindent
  end

  def indent(string, n = 2)
    string.indent(n)
  end

##
#
  def reserved_routes
    @reserved_routes ||= (
      anything_in_public =
        Dir[File.join(Rails.root, "public/*")].map {|file| File.basename(file)}

      begin
        route_prefixes =
          Rails.application.routes.routes.
            map{|route| route.path.spec.to_s}.
            map{|path| path[%r|[^/)(.:]+|]}.
            compact.sort.uniq
      rescue Object
        route_prefixes = []
      end

      blacklist = %w[
        index
        new
        create
        update
        show
        delete
        destroy
        ajax
        call
        callback
      ]

      basenames = (
        anything_in_public +
        route_prefixes +
        blacklist
      ).map{|_| File.basename(_)}

      (
        basenames +
        basenames.map{|basename| basename.split('.', 2).first}
      ).sort.uniq
    )
  end

##
#
  BSON = defined?(Moped::BSON) ? Moped::BSON : BSON

  def id_for(model_or_id)
    id = model_or_id.is_a?(Mongoid::Document) ? model_or_id.id : model_or_id
    case id
      when BSON::ObjectId
        id
      else
        BSON::ObjectId(id.to_s)
    end
  end

##
#
  def Util.dos2unix(string)
    string = string.to_s
    string.gsub!(%r/\r\n/, "\n")
    string.gsub!(%r/\r/, "\n")
    string
  end

##
#
  def Util.cases_for(*args)
    options = args.extract_options!.to_options!

    title = args.shift || options[:title]
    slug = args.shift || options[:slug]
    name = args.shift || options[:name]

    cases = Map.new(:title => title, :slug => slug, :name => name)

    if cases.name.blank?
      case
        when title
          cases.name = Slug.for(title, :join => '_')
        when slug
          cases.name = Slug.for(slug, :join => '_')
      end
    end

    if cases.slug.blank?
      case
        when name
          cases.slug = Slug.for(name, :join => '-')
        when title
          cases.slug = Slug.for(title, :join => '-')
      end
    end

    if cases.title.blank?
      case
        when name
          cases.title = String(cases.name).strip.titleize
        when slug
          cases.title = String(cases.slug).strip.titleize
      end
    end

    unless cases.name.blank?
      cases.name = Slug.for(cases.name, :join => '_')
    end

    unless cases.slug.blank?
      cases.slug = Slug.for(cases.slug, :join => '-')
    end

    unless cases.title.blank?
      cases.title = String(cases.title)
    end

    cases
  end

  extend Util
  #unloadable(Util)
end
