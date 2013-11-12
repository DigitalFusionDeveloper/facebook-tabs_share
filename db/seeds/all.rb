## root
#
  seed "setup the root user", :guard => User.root? do
    root = 
      User.make!(
        :name     => "root",
        :email    => "root",
        :root     => true,
        :roles    => %w( admin su )
      )
  end

## stakeholders all get dem accounts for free
#
  stakeholders =
  [
    {
      :email => 'dojo4@dojo4.com', :name => 'dojo4',
      :email => 'sheena.collins@mobilefusion.com', :name => 'Sheena Collins',
      :email => 'corey.inouye@mobilefusion.com', :name => 'Corey Inouye'
    },
  ]

  stakeholders.each do |attributes|
    email = attributes[:email]

    seed "setup #{ email }", :guard => User.where(:email => email).first do
      user = User.make!(attributes).tap{|user| user.admin!}
    end
  end

## setup jane and john users
#
=begin
  unless Rails.env.production?
    jane = User.jane rescue false
    john = User.john rescue false

    seed 'jane', :unless => jane do
      User.make!(:name => 'Jane Doe', :email => 'jane@doe.com')
    end

    seed 'john', :unless => john do
      User.make!(:name => 'John Doe', :email => 'john@doe.com')
    end
  end
=end

unless Rails.env.production?
  seed 'locations', :if => Location.count.zero? do
    glob = Rails.root.join('db/brands/locations/seed/*.csv').to_s

    Dir.glob(glob).each do |entry|
      slug = File.basename(entry).split('.').first
      brand = Brand.for(slug)

      if brand
        csv = IO.binread(entry) 
        importer = Location::Importer.new(:brand => brand.slug, :csv => csv)
        importer.parse && importer.save
        Location.locate_all!
      end
    end
  end
end

##
#
#  unless Rails.env.production?
    users = User.where(:password_digest => nil)

    seed "set default passwords", :unless => users.size.zero?  do
      users.each do |user|
        user.password = user.email
        user.save!
      end
    end
#  end

##
#
=begin
  seed "enums", :guard => Enum.count > 0 do
    yaml = IO.read("#{ Rails.root }/db/seeds/data/enums.yml")
    definitions = YAML.load(yaml)
   
    definitions.each do |name, definition|
      enum = Enum.define(name, definition)
    end
  end
=end
