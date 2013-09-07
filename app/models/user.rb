class User
##
#
  include App::Document

## schema
#
  field(:email)

  field(:name)
  field(:first_name)
  field(:last_name)

  field(:password_digest)

  field(:roles, :type => Array, :default => [])
  field(:logged_in_at, :type => Time, :default => nil)
  field(:session, :type => Hash, :default => proc { Hash.new })

  field(:root)

## relationships
#
  has_many(:tokens, :as => :context, :dependent => :destroy)

## validations, etc
#
  validates_presence_of(:email)
  validates_uniqueness_of(:email)
  validates_format_of(:email, :with => Util.patterns.email, :unless => proc{ root? or has_role?(:su) })

## indexes
#
  index({:email => 1}, {:unique => true})
  index({:roles => 1})
  index({:root => 1}, {:unique => true, :sparse => true})

## lookup shortcuts
#
  User.lookup_by!(:email)

  def User.find_by_email(email)
    find_by(:email => Util.normalize_email(email))
  end

  def User.find_by_email!(email)
    find_by!(:email => Util.normalize_email(email))
  end

##
#
  before_validation do |user|
    user.normalize!
  end

## normalization support
#
  def normalize!
    normalize_email!
    normalize_name!
    normalize_roles!
  end

  def normalize_email!
    self.email = Util.normalize_email(email) unless email.blank?
  end

  def normalize_name!
    if self.name.blank?
      name = [first_name, last_name].join(' ')
      self.name = name unless name.blank?
    end

    if self.name.blank?
      name = email.to_s.split(/@/).first.to_s.scan(/\w+/).map(&:titleize).join(' ')
      self.name = name unless name.blank?
    end

    unless self.name.blank?
      parts = self.name.scan(/\w+/)
      first_name = parts.shift
      last_name = parts.pop
      if self.first_name.blank?
        self.first_name = first_name unless first_name.blank?
      end
      if self.last_name.blank?
        self.last_name = last_name unless last_name.blank?
      end
    end
  end

  def normalize_roles!
    roles.map!{|role| role.to_s}
    roles.delete_if{|role| role.empty?}
    roles
  end

  def to_s
    email
  end

## simple role support
#
  Roles = %w[ su admin ]

  def User.roles
    Roles
  end

  def add_roles!(*roles)
    roles = Coerce.list_of_strings(roles)
    add_to_set(:roles, roles.flatten.compact)
    roles
  end

  def add_role!(role)
    add_roles!(role).first
  end

  def add_roles(*roles)
    self[:roles] ||= []
    roles = Coerce.list_of_strings(roles)
    self[:roles].push(*roles)
    self[:roles].uniq!
    roles
  end

  def add_role(role)
    add_roles(role).first
  end

  def has_roles?(*roles)
    roles = Coerce.list_of_strings(roles)
    roles.all?{|role| self.roles.include?(role)}
  end

  def has_role?(role)
    has_roles?(role)
  end

  def remove_roles!(*roles)
    roles = Coerce.list_of_strings(roles)
    pull_all(:roles, roles.flatten.compact)
    roles
  end

  def remove_role!(role)
    remove_roles!(role).first
  end

  def remove_roles(*roles)
    roles = Coerce.list_of_strings(roles)
    roles.each{|role| self.roles.delete(role)}
    roles
  end

  def remove_role(role)
    remove_roles(role).first
  end

  Roles.each do |role|
    role_method = role.to_s.underscore.gsub('/', '__')

    module_eval <<-__, __FILE__, __LINE__
      def #{ role_method }!
        add_role!(#{ role.inspect })
      end

      def not_#{ role_method }!
        remove_role!(#{ role.inspect })
      end

      def #{ role_method }?
        has_role?(#{ role.inspect })
      end
    __
  end

  def admin?
    root? or roles.include?('su') or roles.include?('admin')
  end

## password encryption
#
  def password=(password)
    if password.blank?
      write_attribute(:password_digest, nil)
    else
      password = password.to_s
      password = BCrypt::Password.create(password) unless password[0,1] == '$'
      write_attribute(:password_digest, password)
    end
  end

  def password
    password = read_attribute(:password_digest)
    BCrypt::Password.new(password) unless password.blank?
  end

## user factory method
#
  def User.make!(*args, &block)
    options = args.extract_options!.to_options!

    email = args.shift || options.delete(:email)
    password = args.shift || options.delete(:password)

    id = options.delete(:id) || options.delete(:_id)
    roles = options.delete(:roles) || options.delete(:role)

    roles = Array(roles).flatten.compact.map{|role| role.to_s}

    attributes = {
      :email => email,
      :password => password,
    }.merge(options)

    user = new(attributes)

    roles.each do |role|
      user.add_role!(role) unless role.blank?
    end

    user.id = id if id
    user.save!
    user.reload
    user
  end

## auth methods
#
  def User.authenticate(*args)
    options = args.extract_options!.to_options!
    email = args.shift || options[:email]
    password = args.shift || options[:password]

    return nil if email.blank?

    user = User.where(:email => email.strip.downcase).first

    return nil if user.blank?
    return false if user.password.blank?

    user.password == password ? user : false
  end

##
#
  def User.deliver_signup_email(*args)
    options = args.extract_options!.to_options!

    user = args.shift || options[:user] || options[:user_id]
    token = args.shift || options[:token] || options[:token_id]

    user = user.is_a?(User) ? user : User.for(user)

    unless token
      token = user.create_signup_token
    else
      token = token.is_a?(Token) ? token : Token.find(token)
    end

    mail = Mailer.signup(:user => user, :token => token).deliver

    [user, token, mail]
  end

  def deliver_signup_email(*args)
    options = args.extract_options!.to_options!

    user = self
    token = args.shift || options[:token] || options[:token_id]

    unless token
      token = user.create_signup_token
    else
      token = token.is_a?(Token) ? token : Token.find(token)
    end

    job = Job.submit(User, :deliver_signup_email, :user_id => user.id, :token_id => token.id)

    [user, token, job]
  end

  def create_signup_token
    context = self
    Token.make!(context, :kind => :signup)
  end

##
#
  def User.deliver_password_email(*args)
    options = args.extract_options!.to_options!

    user = args.shift || options[:user] || options[:user_id]
    token = args.shift || options[:token] || options[:token_id]

    user = user.is_a?(User) ? user : User.for(user)

    unless token
      token = user.create_password_token
    else
      token = token.is_a?(Token) ? token : Token.find(token)
    end

    mail = Mailer.password(:user => user, :token => token).deliver

    [user, token, mail]
  end

  def deliver_password_email(*args)
    options = args.extract_options!.to_options!

    user = self
    token = args.shift || options[:token] || options[:token_id]

    unless token
      token = user.create_password_token
    else
      token = token.is_a?(Token) ? token : Token.find(token)
    end

    job = Job.submit(User, :deliver_password_email, :user_id => user.id, :token_id => token.id)

    [user, token, job]
  end

  def create_password_token
    context = self
    Token.make!(context, :kind => :password)
  end

## token support
#
  def User.find_by_token(token)
    unless token.is_a?(Token)
      token = Token.where(:context_type => User.name, :uuid => token.to_s).first
    end

    unless token.blank?
      user = token.context
    end
  end

  def User.tokens
    Token.where(:context_type => User.name)
  end

  def User.find_by_token!(token)
    find_by_token(token) or not_found!(:token => token)
  end

  def create_login_token
    context = self
    Token.make!(context, :kind => :login)
  end

  def login_link(*args)
    options = args.extract_options!.to_options!
    token = options[:token] || create_login_token
    App.url(helper.login_path(:token => token))
  end


## root user
#
  def User.root
    User.where(:root => true).first
  end

  def User.root?
    root rescue false
  end

## hack during development
#
  def User.jane
    User.where(:email => 'jane@doe.com').first
  end

  def User.john
    User.where(:email => 'john@doe.com').first
  end

## misc
#
  def member?(object)
    object.member?(self)
  end
end
