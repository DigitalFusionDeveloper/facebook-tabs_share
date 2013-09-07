require 'cgi'

class String
  def String.unindented!(s)
    margin = nil
    s.each_line do |line|
      next if line =~ %r/^\s*$/
      margin = line[%r/^\s*/] and break
    end
    s.gsub! %r/^#{ margin }/, "" if margin
    margin ? s : nil
  end

  def String.unindented s
    s = "#{ s }"
    unindented! s
    s
  end

  def String.random(options = {})
    options.to_options!
    Kernel.srand

    default_size = 6
    size = Integer(options.has_key?(:size) ? options[:size] : default_size)

    default_chars = ( ('a' .. 'z').to_a + ('A' .. 'Z').to_a + (0 .. 9).to_a )
    %w( 0 O l ).each{|char| default_chars.delete(char)}

    chars = [ *Array(options[:chars] || default_chars) ].flatten.compact.map{|char| char.to_s}
    Array.new(size).map{ chars[rand(2**32)%chars.size, 1] }.join
  end

  def unindented!
    String.unindented! self
  end
  alias_method('unindent!', 'unindented!')

  def unindented
    String.unindented self
  end
  alias_method('unindent', 'unindented')

  def String.indented!(s, n = 2)
    margin = ' ' * Integer(n)
    unindented!(s).gsub!(%r/^/, margin)
    s
  end

  def String.indented(s, n = 2)
    s = "#{ s }"
    indented! s, n
    s
  end

  def indented!(n = 2)
    String.indented! self, n
  end
  alias_method('indent!', 'indented!')

  def indented(n = 2)
    String.indented self, n
  end
  alias_method('indent', 'indented')

  def String.inlined!(s)
    s.strip!
    s.gsub! %r/([^\n])\n(?!\n)/, '\1 '
  end

  def String.inlined(s)
    s = "#{ s }"
    inlined! s
    s
  end

  def inlined!
    String.inlined! self
  end
  alias_method('inline!', 'inlined!')

  def inlined
    String.inlined self
  end
  alias_method('inline', 'inlined')

  def solid
    gsub(/\n/, '<br />').gsub(/\t/, '&nbsp;&nbsp;').gsub(/\s/, '&nbsp;')
  end

  def slug
    Slug.for(self)
  end

  def / other
    File.join self, other.to_s
  end

  def quoted
    "<b style='font-size:large'>&ldquo;</b>#{ self }<b style='font-size:large'>&rdquo;</b>"
  end

  def escapeHTML
    CGI.escapeHTML(self)
  end

  def escape_html
    CGI.escapeHTML(self)
  end

  def wrapped(options = {})
    options.to_options!
    with = options[:with]
    unless options[:empty]
      return to_s if empty?
    end
    with = with.to_s.split(//) unless with.is_a?(Array)
    first, last = with[0...with.size/2], with[with.size/2..-1]
    "#{ first }#{ to_s }#{ last }"
  end

  def ellipsis n = 42 
    size >= n ? "#{ slice(0, n - 3) }..." : self
  end

  def url(query)
    query_string = query.is_a?(Hash) ? query.query_string : query_string
    base = dup
    base.sub!(/[?]+$/, '')
    query_string.sub!(/^[?]+/, '')
    unless query_string.blank?
      "#{ base }?#{ query_string }"
    else
      "#{ base }"
    end
  end
end

class Array
  def to_csv
    require 'csv' unless defined?(CSV)
    returning(string = String.new) do
      CSV::Writer.generate(string){|csv| each{|record| csv << record}}
    end
  end
end

class Object
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
end

class Numeric
  def parity
    (self.to_i % 2) == 0 ? 'even' : 'odd'
  end
end

class Fixnum
  LONG_MAX = ( (2 ** (64 - 2)) - 1 )
  INT_MAX = ( (2 ** (32 - 2)) - 1 )

  if LONG_MAX.class == Fixnum
    N_BYTES = 8
    N_BITS = 64
    MAX = LONG_MAX
    MIN = -MAX - 1
  else
    N_BYTES = 4
    N_BITS = 32 
    MAX = INT_MAX
    MIN = -MAX - 1
  end

  def Fixnum.max() MAX end
  def Fixnum.min() MIN end

  raise('bad Fixnum.max') unless (Fixnum.max + 1).class == Bignum
end

class Float
  PositiveInfinity = 42.0/0.0
  NegativeInfinity = -42.0/0.0
  Infinity = PositiveInfinity
  #def Infinity.+@() Infinity end
  #def Infinity.-@() Infinity end
  def Float.infinity() Infinity end
end 

class Time
  def Time.starts_at
    @starts_at ||= Time.at(0).utc
  end

  def Time.ends_at
    @ends_at ||= Time.parse('03:14:07 UTC on Tuesday, 19 January 2038')
  end
end

class Dir
  require 'tmpdir'
  Tmpdir = method(:tmpdir)

  def Dir.tmpdir(&block)
    return Tmpdir.call() unless block
    basename = [Process.ppid.to_s, Process.pid.to_s, Thread.current.object_id.abs.to_s, Time.now.to_f, rand.to_s].join('-')
    dirname = File.join(tmpdir, basename)
    FileUtils.mkdir_p(dirname)
    begin
      Dir.chdir(dirname) do
        return block.call(Dir.pwd)
      end
    ensure
      FileUtils.rm_rf(dirname) rescue "system rm -rf #{ dirname.inspect }"
    end
  end
end

class Hash
  def to_query_string(options = {})
    options.to_options!
    escape = options.has_key?(:escape) ? options[:escape] : true
    pairs = [] 
    esc = escape ? proc{|v| CGI.escape(v.to_s)} : proc{|v| v.to_s}
    each do |key, values|
      key = key.to_s
      values = [values].flatten
      values.each do |value|
        value = value.to_s
        if value.empty?
          pairs << [ esc[key] ]
        else
          pairs << [ esc[key], esc[value] ].join('=')
        end
      end
    end
    pairs.replace pairs.sort_by{|pair| pair.size}
    pairs.join('&')
  end
  alias_method :query_string, :to_query_string

  def to_css
    css = ''
    if defined?(Helper)
      h = Helper.new
      esc = proc{|x| h.strip_tags(x.to_s).strip}
    else
      esc = proc{|x| x.to_s}
    end

    if values.grep(Hash).first
      each do |key, val|
        css << "#{ esc[key] }\n#{ val.to_css }\n"
      end
    else
      css << "{\n"
      each do |key, val|
        css << "  #{ esc[key] }: #{ esc[val] };"
      end
      css << "\n}"
    end

    css
  end

  def html_options
    to_a.map{|k,v| "#{ k }=#{ CGI.escapeHTML(v).inspect }"}.join(' ')
  end

  def html_attributes
    map{|k,v| [k, v.to_s.inspect].join('=')}.join(' ') 
  end
        
  def select! *a, &b
    replace(select(*a, &b).to_hash)
  end
end

class Proc
# call a block with a list of args adjusted to it's actual arity
#
  def acall(*args)
    call(*Util.args_for_arity(args, arity))
  end
end
