class Mailer < ActionMailer::Base
  default_url_options.merge(
    DefaultUrlOptions
  )

  default(
    :from => App.email
  )

  def test(email)
    mail(:to => email, :subject => 'test')
  end

  def welcome(email, subject, welcome)
    @email = email
    @subject = subject
    @welcome = welcome
    mail(:to => @email, :subject => @subject)
  end

  def text(email, *args)
    options = args.extract_options!.to_options!

    @subject = subject_for(args.shift || options[:subject])
    @text = args.shift || options[:text] || @subject

    mail(:to => email, :subject => @subject)
  end

  def signup(*args)
    options = args.extract_options!.to_options!
    @user = args.shift || options.fetch(:user)
    @token = args.shift || options[:token] || @user.create_signup_token
    @email = @user.email
    @activation_url = activate_path(:token => @token.to_s, :only_path => false)
    @subject = subject_for("Please activate your account.")
    mail(:to => @email, :subject => @subject)
  end

  def password(*args)
    options = args.extract_options!.to_options!
    @user = args.shift || options.fetch(:user)
    @token = args.shift || options[:token] || @user.create_password_token
    @email = @user.email
    @password_url = password_path(:token => @token.to_s, :only_path => false)
    @subject = subject_for("Please reset your password.")
    mail(:to => @email, :subject => @subject)
  end

  def invitation(*args)
    options = args.extract_options!.to_options!

    @invitation = args.shift || options.fetch(:invitation)
    @invitation = @invitation.is_a?(Invitation) ? @invitation : Invitation.find(@invitation)

    @email = @invitation.email
    @subject = subject_for @invitation.subject

    mail(:to => @email, :subject => @subject)
  end

protected
  def Mailer.subject_for(*args)
    ["[#{ App.title }]", *args.compact.flatten].join(' ')
  end
  def subject_for(*args)
    Mailer.subject_for(*args)
  end
  helper_method(:subject_for)

  def Mailer.signature
    "-- Thanks from the #{ App.title } team."
  end
  def signature
    Mailer.signature
  end
  helper_method(:signature)
end
