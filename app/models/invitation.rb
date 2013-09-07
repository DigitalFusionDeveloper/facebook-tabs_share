class Invitation
##
#
  include App::Document

##
#
  field(:_id, :type => String, :default => proc{ App.uuid })
  field(:kind, :type => String, :default => 'default')

  belongs_to(:user)
  belongs_to(:context, :polymorphic => true)

  field(:email)
  field(:subject, :default => proc{ "Please accept this invitation." })
  field(:message)
  field(:return_to)
  field(:viewed, :default => false)

  Fattr(:mailer){ 'Mailer' }
  field(:mailer, :default => Invitation.mailer)

  Fattr(:mailer_method){ 'invitation' }
  field(:mailer_method, :default => Invitation.mailer_method)

  field(:data, :type => type_for('map'), :default => proc{ Map.new })

  field(:delivery_count, :default => 0)

  Statuses = %w( pending accepted declined revoked )

  field(:status)

##
#
  validates_presence_of(:kind)
  validates_presence_of(:subject)
  validates_presence_of(:message)
  validates_presence_of(:email)
  validates_inclusion_of(:status, :in => Statuses, :if => proc{ status })

  before_save do |invitation|
    invitation.normalize_message!
  end

  def normalize_message!
    self.message = self.message.to_s.unindented unless self.message.blank?
  end

  Statuses.each do |status|
    module_eval <<-__, __FILE__, __LINE__
      def #{ status }?
        status == #{ status.inspect }
      end

      def #{ status }!
        update_attributes!(:status => #{ status.inspect })
      end
    __
  end

  def viewed?
    viewed
  end

  def viewed!
    update_attributes!(:viewed => true)
  end

  def deliver
    mail = eval(mailer).send(:new, mailer_method, id).message
    mail.deliver

    inc(:delivery_count, 1)
    pending!

    mail
  end

  def Invitation.deliver(id)
    find(id).deliver
  end

  def to_mail
    mailer.to_s.constantize.send(mailer_method.to_s, self.id)
  end

  def to_mail_html
    to_mail.body
  end

  def Invitation.deliver!(attributes = {})
    invitation = create!(attributes)
    invitation.deliver!
    invitation
  end

  def callback(user)
    invitation = self
    data = Map.new(invitation.data)

    update_attributes(:user_id => user.id)

    result =
      case kind
        when 'default'
          raise NotImplementedError
      end

    invitation.accepted!

    result
  end

  def helper
    @helper ||= Helper.new
  end

  def url
    helper.invitation_path(id, :only_path => false)
  end
end
