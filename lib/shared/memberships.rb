Shared(:memberships) do
  parent_class      = self
  parent_class_name = parent_class.name

  index({"memberships.roles" => 1})
  index({"memberships.user_id" => 1})

  const_set(:Membership, Class.new)

  membership_class = const_get(:Membership)
  membership_class_name = "#{ parent_class_name }::Membership"

  define_method(:membership_class){ membership_class }

  parent_class.instance_eval do
    Fattr(:membership_roles){ %w( admin member ) } unless
      respond_to?(:membership_roles)

    Fattr(:membership_default_roles){ %w( admin member ) } unless
      respond_to?(:membership_default_roles)

    Fattr(:membership_default_role){ "member" } unless
      respond_to?(:membership_default_role)
  end

  membership_class.class_eval do
    include App::Document::Embedded

    field(:email)

    belongs_to(:user)

    field(:roles, :type => Array, :default => parent_class.membership_default_roles)

    validates_presence_of(:user)
    validates_presence_of(:roles)

    before_save do |membership|
      membership.email = user.email if user
    end

    def add_role(role)
      roles = self.roles
      roles.push(role.to_s)
      roles.uniq!
      self.roles = roles
    end

    def add_role!(role)
      roles = self.roles
      roles.push(role.to_s)
      roles.uniq!
      update_attributes!(:roles => roles)
    end
  end
  membership_class.send(:embedded_in, parent_class_name.underscore, :class_name => parent_class_name)
  membership_class.send(:define_method, :context){ send(parent_class_name.underscore) }
  embeds_many(:memberships, :class_name => membership_class_name)

  def add_membership(user, *args)
    options = args.extract_options!.to_options!

    roles = [args, options[:role], options[:roles]].flatten.compact
    roles.push(parent_class.membership_default_roles) if roles.empty?
    roles.flatten!
    roles.compact!
    roles.map!{|role| role.to_s}

    user_id = user.is_a?(User) ? user.id : user
    email = user.is_a?(User) ? user.email : User.find(user).email
    membership = memberships.detect{|_| _.user_id == user_id}

    if membership
      roles = (membership.roles + roles).uniq
      membership.update_attributes!(:roles => roles)
    else
      membership = memberships.build(:email => email, :user_id => user_id, :roles => roles)
    end
    membership
  end

  def add_membership!(user, *args)
    membership = add_membership(user, *args)
    membership.save!
    membership
  end

  def membership_for(user)
    id = user.is_a?(User) ? user.id : user 
    memberships.detect{|_| _.user_id == id}
  end

  def membership_with_role?(user, *roles)
    membership = membership_for(user)
    roles = [roles].flatten.compact.map{|role| role.to_s}
    roles.push(membership_class.membership_default_role) if roles.empty?
    return false unless membership
    roles.all?{|role| membership.roles.include?(role)}
  end

  parent_class.membership_roles.each do |role|
    class_eval <<-__, __FILE__, __LINE__
      def add_#{ role }(user_or_email)
        add_membership(user_or_email, :#{ role })
      end

      def add_#{ role }!(user_or_email)
        add_membership!(user_or_email, :#{ role })
      end

      def #{ role }?(user)
        membership_with_role?(user, :#{ role })
      end

      def self.where_#{ role }( user )
        where :memberships.matches => { :roles.in => [ "#{ role }" ] , :user_id => Util.id_for( user ) }
      end
    __
  end

  def member?(user)
    !!membership_for(user)
  end

  def members
    user_ids = memberships.map{|m| m.user_id}
    User.where(:_id.in => user_ids)
  end

  def membership_roles_for(user)
    membership_for(user).try(:roles) || []
  end

  def remove_member(user)
    id = user.is_a?(User) ? user.id : user 
    membership = memberships.detect{|_| _.user_id == id}
    membership.destroy
  end

  class << parent_class
  ## Generic Parent Class Query Helpers / Finders
  #
    # Find instances of the parent class for which the user has a membership
    def for_member( user )
      where "memberships.user_id" => Util.id_for( user )
    end
  end
end
