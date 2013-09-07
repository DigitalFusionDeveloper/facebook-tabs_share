class Token
  include App::Document

  belongs_to(:context, :polymorphic => true)

  field(:kind, :type => String)

  field(:uuid, :type => String, :default => proc{ App.uuid })
  field(:data, :type => App::Document::Type::Map, :default => proc{ Map.new })

  field(:expired, :type => Boolean, :default => false)
  field(:expires_at, :type => Time)

  validates_presence_of(:uuid)

  def Token.make!(*args, &block)
    options = args.extract_options!.to_options!
    context = args.shift || options.delete(:context)
    options.update(:context => context) unless context.blank?
    token = Token.create!(options)
  end

  def Token.for(arg)
    case arg
      when Token
        arg
      when App::Document, Mongoid::Document
        Token.find_by_context(arg)
      else
        Token.where(:uuid => arg.to_s).first
    end
  end

  def Token.find_by_context(doc)
    Token.find_by(:context_type => doc.class.name, :context_id => doc.id)
  end

  def Token.find_by_context!(doc)
    Token.find_by!(:context_type => doc.class.name, :context_id => doc.id)
  end

  def Token.context_for(arg)
    token = Token.for(arg)
    token.context if token
  end

  def expired?
    expired || (expires_at and expires_at < Time.now)
  end

  def expire!
    update_attributes(:expired => true)
  end

  def expires_in=(t)
    self.expires_at = Time.now.utc + t
  end

  def expires_in
    if expires_at
      expires_at - Time.now.utc
    end
  end

  def to_s
    uuid
  end

  def to_param
    uuid
  end

  def value
    uuid
  end
end
