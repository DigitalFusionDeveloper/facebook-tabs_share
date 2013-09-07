begin
  require 'rubygems'
rescue LoadError
end

begin
  require 'stringx'
rescue LoadError
end

class Slug < ::String
  Join = '-'

  def Slug.for(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    join = (options[:join]||options['join']||Join).to_s
    string = args.flatten.compact.join(join)
    string = unidecode(string).titleize
    words = string.to_s.scan(%r|[/\w]+|)
    words.map!{|word| word.gsub %r|[^/0-9a-zA-Z_-]|, ''}
    words.delete_if{|word| word.nil? or word.strip.empty?}
    new(words.join(join).downcase.gsub('/', (join * 2)))
  end

  unless defined?(Stringex::Unidecoder)
    def Slug.unidecode(string)
      string
    end
  else
    def Slug.unidecode(string)
      Stringex::Unidecoder.decode(string)
    end
  end
end
