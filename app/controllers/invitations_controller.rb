class InvitationsController < ApplicationController
  before_filter(:setup)

  def show
    @invitation.viewed!
  end

  def decline
  ##
  #
    if @invitation.accepted?
      message("This invitation has already been accepted.", :class => :error)
      redirect_to('/')
    end

  ##
  #
    @invitation.declined!
    message("The invitation has been declined.")
    redirect_to('/')
  end

  def accept
  ##
  #
    if @invitation.declined?
      message("This invitation has already been declined.", :class => :error)
      redirect_to('/')
    end

  ## we'll be tracking 'accepts' from non-authenticated users
  #
    session[:invitations] = Array(session.delete(:invitations))
    invitation_ids = session[:invitations]

  ## for non-authenticated users track the acceptance and move them onto the
  # authenticated path (login or signup)
  #
    unless current_user
      invitation_ids.push(@invitation.id)
      email = @invitation.email

      url =
        if User.where(:email => email).exists?
          message("Please log in to accept this invitation.", :class => :error)
          login_path(:email => email)
        else
          message("Please sign up (or log in) to accept this invitation.", :class => :error)
          signup_path(:email => email)
        end

      redirect_to(url)
      return
    end

  ## process all outstanding accepted invitations, including the current one
  #
    invitations = Invitation.where(:_id.in => invitation_ids) + [@invitation]

    begin
      invitations.uniq.each do |invitation|
        begin
          unless invitation.accepted?
            invitation.callback(current_user)
          end
          invitation_ids.delete(invitation.id)
        rescue
          raise if invitation == @invitation
        end
      end
    ensure
      if invitation_ids.blank?
        session.delete(:invitations)
      else
        session[:invitations] = invitation_ids
      end
    end

  ## redirect based on the current one
  #
    message("Thank you, the #{ @invitation.kind.inspect } invitation has been accepted.")
    redirect_to(@invitation.return_to || '/')
  end

protected
  def setup
    @invitation = Invitation.find(params[:id])

    if @invitation.revoked?
      message("This invitation has been #{ @invitation.status }.")
      redirect_to('/')
    end
  end
end
