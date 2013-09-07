class Enum
##
#
  include App::Document

##
#
  name_fields!

  field(:position, :default => proc{ default_position }, :type => Integer)

  filtered_field(:help)

##
#
  validates_uniqueness_of(:name)

##
#
  lookup_by!(:name)

##
#
  default_scope(order_by(:position => :asc))

##
#
  before_save do |enum|
    enum.description = enum.title if enum.description.blank?
  end

##
#
  index({'name' => 1}, {:unique => true})
  index({'values._id' => 1}, {:unique => true})

##
#
  class Value
    include App::Document::Embedded

    name_fields!

    validates_uniqueness_of(:name)

    field(:enum_id)

    before_save do |value|
      value.enum_id = enum.id unless enum.blank? 
    end

    embedded_in(:enum)

    alias_method('__enum__', 'enum')

    def enum
      __enum__ || (enum_id ? (@enum ||= Enum.find(enum_id)) : nil)
    end

    def to_s
      title
    end

    def value
      title
    end

    def Value.find(id)
      id = id_for(id)
      enum = Enum.where('values._id' => id).first
      Enum.not_found!('values._id' => id) unless enum
      enum.values.find(id)
    end
  end
  embeds_many(:values, :class_name => '::Enum::Value', :cascade_callbacks => true)

##
#
  module DSL
    ClassMethods = proc do
      def define(name, *args)
        new(:name => name).tap do |enum|
          options = args.extract_options!.to_options!
          values = [args, options.delete(:values), options.delete(:value)].compact.flatten
          attributes = options
          enum.add_values(*values)
          enum.update_attributes(attributes)
          enum.save!
        end
      end
    end

    InstanceMethods = proc do
      def add_values(*values)
        values.flatten.map do |value|
          attributes =
            case value
              when Value
                value.attributes
              when Hash
                value
              else
                {:name => value.to_s}
            end.to_options
          value = self.values.build(attributes)
        end
      end
    end

    def DSL.included(other)
      super
    ensure
      other.send(:class_eval, &InstanceMethods)
      other.send(:instance_eval, &ClassMethods)
    end
  end

  include(DSL)

##
#
  class << Enum
    def names
      all.map(&:name)
    end

    def to_map
      Map.new.tap do |map|
        Enum.names.each do |name|
          enum = Enum[name]
          values = enum.values.map(&:name)
          map[name] = values
        end
      end
    end

    def to_hash
      to_map.to_hash
    end

    def method_missing(method, *args, &block)
      case method.to_s
        when /\A(.*)=\Z/
          name = $1
          Enum.define(name, *args)
        else
          name = method.to_s
          where(:name => name).first || super
      end
    end

    def [](name)
      find_by!(:name => name)
    end
  end

##
#
  def default_position
    klass.all.count
  end

  def to_s
    title.html_safe
  end

  def options_for_select(*args, &block)
    options = args.extract_options!.to_options!
    blank = options[:blank]
    list = values.map{|value| [value.title, {:value => value.id, :title => value.description}]}
    list.unshift [nil,nil] if blank
    list
  end

  def value_names
    values.map(&:name)
  end

  def Enum.value_for(enum_conditions, value_conditions)
    conditions =
      case enum_conditions
        when Hash
          enum_conditions
        else
          s = enum_conditions.to_s
          { '$or' => [ {:_id => s}, {:id => s}, {:name => s} ] }
      end
    Enum.find_by!(conditions).value_for(value_conditions)
  end

  def value_for(id_or_name)
    s = id_or_name.to_s
    value = values.detect{|v| v._id.to_s == s or v.id.to_s == s or v.name.to_s == s}

    unless value
      Enum::Value.not_found!('$or' => [{:_id => s}, {:id => s}, {:name => s}])
    else
      value
    end
  end

  def [](id_or_name)
    value_for(id_or_name)
  end
end
