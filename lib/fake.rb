module Fake
  class Image < ::String
    Prefix = File.join(Rails.root, 'public', 'fake', 'images')
    Glob = File.join(Prefix, '*')

    attr_accessor :path

    def initialize(url)
      replace(Util.absolute_path_for(url))
    end

    def url(*args)
      self
    end

    def Image.all
      public_path = Pathname.new(Rails.public_path)

      all = []

      Dir.glob(Glob).each do |entry|
        path = File.expand_path(entry)
        url = Pathname.new(path).relative_path_from(public_path).to_s

        image = Image.new(url)
        image.path = path

        all.push(image)
      end

      all
    end
  end

  Images = Image.all

  def uuid
    App.uuid
  end

  def image
    Images.sort_by{ rand }.first
  end

  def background_image 
    Images.sort_by{ rand }.first
  end

  def logo
    Images.sort_by{ rand }.first
  end

  def addresses
    [
      "74 rue championnet, paris",
      "2030 17th street, boulder, co, 80302",
      "3055 18th street, boulder, co, 80304",
      "3057 18th street, boulder, co, 80304",
      "240 North Independence, palmer, alaska, 99645",
      "denver, co",
      "lakewood, co",
      "casper, wy",
      "la, california",
      "san franciso, ca",
      'anchorage, ak'
    ]
  end

  def address
    addresses.sort_by{ rand }.first
  end

  def slug
    Slug.for(Faker::Lorem.sentence)
  end

  def email
    Faker::Internet.email
  end

  def password
    Fake.word
  end

  def words(options = {})
    size = options[:size] || 1
    Faker::Lorem.words(size)
  end

  def word
    Fake.words.first
  end

  def name(options = {})
    size = options[:size] || 1
    Faker::Lorem.words(size).join(' ')
  end

  def first_name
    Faker::Name.first_name
  end

  def last_name 
    Faker::Name.last_name
  end

  def full_name
    Faker::Name.name
  end

  def credit_card
    today = Date.today

    #credit_card = ActiveMerchant::Billing::CreditCard.new(
    credit_card = {
      :number     => '4111111111111111',
      :year       => today.year + 1,
      :month      => today.month,
      :first_name => Fake.first_name,
      :last_name  => Fake.last_name,
      :verification_value  => Fake.cvv 
    }
  end

  def cvv
    [rand(10), rand(10), rand(10)].join
  end

  def title
    Faker::Lorem.sentence
  end

  def question
    Faker::Lorem.sentences(3).join(' ')
  end

  def description
    Faker::Lorem.paragraphs(2).join(' ')
  end

  def word
    Faker::Lorem.words(1).first
  end

  def sentence
    Faker::Lorem.sentences(1).first
  end

  def paragraphs
    Faker::Lorem.paragraphs(4)
  end

  def paragraph
    Faker::Lorem.paragraphs(1)
  end

  def markdown(n = 3)
    markdown = []

    candidates =
      Dir.glob(File.join(Rails.root, 'db/fake/markdown/*')).
        sort_by{ rand }.
          map{|md| IO.read(md)}

    (rand(n) + 1).times do
      markdown << candidates.shift
    end

    (rand(n) + 1).times do
      markdown << fenced_codeblock
    end

    (rand(n) + 1).times do
      markdown << markdown_image
    end

    (rand(n) + 1).times do
      markdown << paragraph 
    end

    markdown.sort_by{ rand }.join("\n\n")
  end

  def markdown_image
    url = Fake.image.url
    title = Fake.title
    text = Fake.word
    "![#{ text }](#{ url } \"#{ title }\")"
  end

  def fenced_codeblock
    r = rand
    code =
      case
        when r < 0.33
          <<-__
            ```ruby
              class C
                X = 42

                def foo
                  @bar ||= 'foobar'
                end
              end
            ```
          __
        when r < 0.66
          <<-__
            ```bash
              export VAR=42
            ```
          __
        else
          <<-__
            ```html
              <html>
                <meta value='teh valuez' >
                <body>
                </body>
              </html>
            ```
          __
      end
    Util.unindent(code)
  end

  extend(Fake)
end
