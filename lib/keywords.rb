# encoding: utf-8

begin
  require 'rubygems' unless defined?(Gem)
rescue LoadError
  nil
end

begin
  require 'fast_stemmer'
rescue LoadError
  begin
    require 'stemmer'
  rescue LoadError
    abort("keywords.rb requires either the 'fast-stemmer' or 'ruby-stemmer' gems")
  end
end

module Keywords
  def extract(*args)
    string = args.join(' ')
    words = string.scan(/[\w._-]+/)
    keywords = []
    words.each do |word|
      word = word.downcase
      stem = word.stem.downcase
      next if Stopwords.stopword?(word)
      next if Stopwords.stopword?(stem)
      keywords.push(stem)
    end
    keywords
  end

  alias_method('for', 'extract')

  module Stopwords
    glob = File.join(Rails.root, 'lib', 'keywords', 'stopwords', '*.txt')

    List = {}

    Dir.glob(glob).each do |wordlist|
      basename = File.basename(wordlist)
      name = basename.split(/\./).first

      open(wordlist) do |fd|
        lines = fd.readlines
        words = lines.map{|line| line.strip}
        words.delete_if{|word| word.empty?}
        words.push('')
        List[name] = words
      end
    end

    unless defined?(All)
      All = []
      All.concat(List['english'])
      All.concat(List['full_english'])
      All.concat(List['extended_english'])
      #All.concat(List['full_french'])
      #All.concat(List['full_spanish'])
      #All.concat(List['full_portuguese'])
      #All.concat(List['full_italian'])
      #All.concat(List['full_german'])
      #All.concat(List['full_dutch'])
      #All.concat(List['full_norwegian'])
      #All.concat(List['full_danish'])
      #All.concat(List['full_russian'])
      #All.concat(List['full_russian_koi8_r'])
      #All.concat(List['full_finnish'])
      All.sort!
      All.uniq!
    end

    unless defined?(Index)
      Index = {}

      All.each do |word|
        Index[word] = word
      end
    end

    def stopword?(word)
      !!Index[word]
    end

    extend(Stopwords)
  end

  extend(Keywords)
end

if $0 == __FILE__
  p Keywords.extract("the foobars foo-bars foos bars cat and mountains")
end
