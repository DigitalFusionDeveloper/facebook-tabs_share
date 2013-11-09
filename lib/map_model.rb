class MapModel < Map
  module Naming
    def normalize_names!
      title, slug, name = %w( title slug name ).map{|attr| get(attr)}

      Naming.names_for(title, slug, name).tap do |cases|
        self[:title] = cases.title
        self[:slug] = cases.slug
        self[:name] = cases.name
      end

      self
    end

    def Naming.names_for(*args)
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

    def self.included(other)
      super
    ensure
      other.class_eval do
        set_callback(:initialize, :after, :normalize_names!)
      end
    end
  end

  class << MapModel
    def model_name(*args)
      @model_name ||= ActiveModel::Name.new(Map.new(:name => self.name.to_s))

      unless args.empty?
        self.model_name = args.first
      end

      @model_name
    end

    def model_name=(name)
      @model_name = ActiveModel::Name.new(Map.new(:name => name.to_s))
    end

    def identifier(*args)
      @identifier ||= :slug

      unless args.empty?
        self.identifier = args.first
      end

      @identifier
    end

    def identifier=(identifier)
      @identifier = identifier.to_s.to_sym
    end

    def for(arg)
      return arg if arg.is_a?(self)
      return nil if arg.blank?

      target =
        case arg
          when Hash
            String(Map.for(arg)[identifier])
          when String, Symbol
            String(arg)
          else
            nil
        end

      raise(ArgumentError, arg.inspect) if target.nil?

      all.detect do |model|
        model.get(identifier).to_s == target
      end
    end

    def [](arg)
      self.for(arg)
    end

    def all
      @all ||= []
    end

    def list
      all
    end

    def first(*args)
      all.first(*args)
    end

    def last(*args)
      all.last(*args)
    end

    def select(*args)
      all.select(*args)
    end

    def detect(*args)
      all.detect(*args)
    end

    def create(attributes = {})
      model = new(attributes)
    ensure
      all.push(model)
      all.sort!
    end

    def delete_all
      all.clear
    end

    def exists?(id)
      all.detect{|model| model.id.to_s == id.to_s}
    end

    def db_yml
      File.join(Rails.root.to_s, "db/#{ model_name.plural }.yml")
    end

    def db
      @db ||= (
        if test(?s, db_yml)
          db = YAML::load(ERB.new((IO.read(db_yml))).result)
          raise LoadError.new("#{ db_yml } is a #{ db.class.name }") unless [Hash, Array].include?(db.class)
          db
        end
      )
    end

    def reload!
      delete_all
      array = Array(db.is_a?(Array) ? db : db[model_name.plural])
      array.map{|attributes| create(attributes)}
      all
    end

    def load!
      reload!
    end

    def attributes(*args)
      @attributes ||= Map.new

      unless args.empty?
        @attributes.clear

        args.each do |arg|
          case arg
            when String, Symbol
              key = arg.to_s
              @attributes.set(key => nil)
            when Array
              Coerce.list_of_strings.each do |key|
                @attributes.set(key => nil)
              end
            when Hash
              @attributes.update(arg)
            else
              raise ArgumentError.new(arg.inspect)
          end
        end
      end

      @attributes
    end

    def attributes=(attributes)
      self.attributes(attributes)
      @attributes
    end

    def normalize!(*args, &block)
      args.push(:after) if args.blank?
      set_callback(:initialize, *args, &block)
    end

    def normalize_names!
      include Naming
    end
  end

  include ActiveSupport::Callbacks
  define_callbacks(:initialize)

  def initialize(*args, &block)
    run_callbacks :initialize do
      self.class.attributes.each do |k,v|
        dup = Marshal.load(Marshal.dump(v))
        set(k => dup)
      end

      attributes = Map.options_for!(args)

      set(attributes)

      if args.size == 1
        send("id=", args.shift)
      end
    end
  end

  set_callback(:initialize, :after, :normalize!)

  def normalize!
    nil
  end

  def id
    get(identifier)
  end

  def id=(id)
    set(identifier, Slug.for(id))
  end

  def identifier
    self.class.identifier
  end

  def <=>(other)
    id.to_s <=> other.id.to_s
  end

  def inspect
    "#{ self.class.name }(#{ to_hash.inspect.chomp })"
  end

  def to_s
    id.to_s
  end

  def to_param
    id.to_s
  end
end

Object.send(:remove_const, :MM) if Object.send(:const_defined?, :MM)

MM = MapModel
