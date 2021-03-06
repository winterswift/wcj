#!ruby
#
# Word Count Journal controller for accounts
# (c) 2006 makalumedia
# 
# 2006-11-20  james.anderson  (#1) successful login or signup should redirect to
#  author's page
# 2006-11-27  alex.bendiken   (#1) removed update action
# 2006-11-30  james.anderson  permission_denied redirects to login
# 

VERSIONS[__FILE__] = "$Id: account_controller.rb 870 2007-02-15 14:41:46Z james $"

class AccountController < ApplicationController
  observer :user_observer
  EMAIL_REGEX = /^(([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Za-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6}$/i
  # access_rule 'user || admin || guest', :only => [:logout]
  
  sidebar :account_login, :only => :signup, :position => 'sidebar'

  def index
    if ( logged_in? )
      redirect_to(:controller => 'users', :user_id=> current_user.id)
    else
      redirect_to(signup_url)
    end
  end

  def login
    if logged_in?
      redirect_to(home_url)
    else
      # puts("account_controller.login()")
      unless request.post?
        return
      end
      self.current_user = User.authenticate(params[:login], params[:password])
      if current_user
        if params[:remember_me] == "1"
          self.current_user.remember_me
          cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
        end
        # if no return location, then redirect to the user's page
        # not to an account list redirect_back_or_default(:controller => 'account', :action => 'index')
        logger.info("logged in user: #{current_user}")
        redirect_back_or_default(:controller => 'users', :action => 'show',
                                 :user_id=> current_user.id())
        flash[:notice] = "Logged in successfully"
      else
        flash[:error] = "Incorrect user name or password"
      end
    end
  end

  # authenticate the user with the expectation that the request includes an authentication token
  # to enroll them in a group. if the login succeeds, then redirect them to GroupsController#add_member
  def login_to_group
    # require continuation parameters and then
    # distinguish already authorized from unauthorized
    # and if unauthorized, get for the form and post
    group = nil; # have to define it first.
    def redirect_to_group (group, authentication)
      #puts("login to group: redirect: current: #{current_user.inspect}")
      #puts("group: #{group}")
      #puts("group: #{group.owner}")
      #puts("authentication: #{authentication}")
      redirect_to(:controller=> 'groups', :action=> 'add_member',
                 :group_id=> group.id, :user_id=> group.owner.id,
                 :member_id=> current_user.id,
                 :add_member=> authentication)
      # puts("redirect")
    end
    
    @authentication = params[:add_member]
    @group_id = params[:group_id]
    # puts("login to group")
    case
    when (@authentication.blank? || @group_id.blank?)
      redirect_to(:action=> :login)
    when ( nil == (group = Group.find(@group_id)) )
      # puts("group not found")
      render(:controller=> 'groups', :action=>:not_found, :status=>"404 Not Found")
    when ( logged_in? )  # catch the case where the user is already logged in
      if ( GroupsController::authenticated?(@authentication){ || GroupsController::add_member_user_authentication(group, current_user) } )
        # go directly to the group page to entroll
        redirect_to_group(group, @authentication)
      else # if not the invited user - new login is required
        flash[:error] = "Already logged in as another user"
      end
    when request.post?
      # process the form results
      # puts("account_controller#login_to_group()")
      self.current_user = User.authenticate(params[:login], params[:password])
      if current_user
        if params[:remember_me] == "1"
          self.current_user.remember_me
          cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
        end
        # redirect to the group's page
        redirect_to_group(group, @authentication)
        flash[:notice] = "Logged in successfully."
      else
        flash[:notice] = "Incorrect user name or password."
      end
    else
      # do nothing and re-render the login form
    end
  end

  # send the user's password to their known address
  def recover_password
    case
    when ((email = params[:email]).blank?)
      flash[:error] = "Please provide an email address."
    when (nil == (@user = (User.find_by_login(email) || User.find_by_email(email))))
      flash[:error] = "No user is associated with the email address '#{email}'."
    when (@user.is_admin?())
      flash[:error] = "No password recovery possible for adminstrators."
      logger.info("recover(): admin password recovery not permitted: #{current_user ? current_user.login : '?'}/#{@user.login}")
    else
      @user.password = @user.recovery_password
      @user.password_confirmation = @user.recovery_password 
      UserNotifier.deliver_recover_password(@user)
      @user.save!
      flash[:notice] = "A new password has been sent to #{@user.email}"
      logger.info("recover(): password recovery sent to: #{@user.email}")
    end
    
    if (logged_in?())
      redirect_back_or_default(:controller => 'users', :action => 'show',
                               :user_id=> current_user.id)
    else
      redirect_back_or_default(:controller => 'account', :action => 'login')
    end
  end
  
  def signup
    sign_up_succeeded_p = false
    if (logged_in? && !(current_user_is_admin?))
      redirect_to(home_url)
      return;
    end
    
    raw_user_params = params[:user] || {}
    user_params = UsersController.filter_attributes(raw_user_params)
    if (utc_offset_string = param('utc_offset', nil, params))
      begin
        utc_offset = Integer(utc_offset_string)
      rescue Exception
        # if the conversion triggered an exception, then it's likely not a legitimate login
        logger.warn("AccountController.signup: Integer('#{utc_offset_string}'): exception: $!. ")
        return
      end
      time_zone = TzinfoTimezone[utc_offset].name
      user_params[:time_zone] = time_zone
    end
    @user = User.new(user_params)
    return unless request.post?
    
    flash[:notice] = ""
    flash[:error] = ""
    # to force for testing, Settings.require_activation = true
    begin
      @user.save!
      flash[:notice] = "Thanks for signing up! A confirmation has been sent to: #{@user.email}"
      flash[:notice] << "<br />"
      flash[:notice] << "<br />"
      flash[:notice] << 'Your account has been created. Please take a few minutes to set your preferences in your profile page. <a href="/users/' + @user.id.to_s + '/edit">Click here</a> to go there now.'
      logger.info("signed-up user: #{@user.inspect()}")
      sign_up_succeeded_p = true
    rescue SystemCallError, Net::SMTPError, Timeout::Error, IOError
      flash[:error] = "Unable to mail to: #{@user.email}"
      flash[:error] << "<br />"
      flash[:error] << "Due to exception: #{$!}"
      logger.warn("signup exception: #{$!}")
    rescue Exception
      flash[:error] = "Unable to complete sign up: #{$!}"
      logger.warn("signup exception: #{$!}")
    end

    # if the sign_up succeeded, then if requiring activation, cause them to
    # login. w/o activation, perform immediate virtual login
    # success recorded explicitly: can't User.authenticate(@user.login, @user.password)
    # as that causes attempt to create a duplicate account to login to it.
    if (Settings.require_activation())
      # if requiring activation, redirect back or to the account page
      if ( sign_up_succeeded_p )
        redirect_back_or_default(:controller => 'account', :action => 'login')
      else
        render :action => 'signup'
      end
    elsif (sign_up_succeeded_p &&
           self.current_user = User.authenticate(@user.login, @user.password) )
      # otherwise, effect login to check password
      # activate user, and redirect to their home page
      current_user.activate!
      redirect_back_or_default(:controller => 'users', :action => 'show',
                               :user_id => current_user.id)
    else
      # if the signup failed, re-render the signup page
      render :action => 'signup'
    end
  end

  def signup_to_group
    sign_up_succeeded_p = false

    def redirect_to_group (group, authentication)
      redirect_to(:controller=> 'groups', :action=> 'add_member',
                 :group_id=> group.id, :user_id=> group.owner.id,
                 :member_id=> current_user.id,
                 :add_member=> authentication)
    end
    
    @authentication = params[:add_member]
    @group_id = params[:group_id]
    flash[:notice] = ""
    flash[:error] = ""
    
    raw_user_params = params[:user] || {}
    user_params = UsersController.filter_attributes(raw_user_params)
    if (utc_offset_string = param('utc_offset', nil, params))
      utc_offset = Integer(utc_offset_string)
      time_zone = TzinfoTimezone[utc_offset].name
      user_params[:time_zone] = time_zone
    end
    @user = User.new(user_params)
    
    case
    when (@authentication.blank? || @group_id.blank?)
      redirect_to(:action=> :signup)
    when ( nil == (group = Group.find(@group_id)) )
      render(:controller=> 'groups', :action=>:not_found, :status=>"404 Not Found")
    when ( logged_in? )  # catch the case where the user is already logged in
      if ( GroupsController::authenticated?(@authentication){ || GroupsController::add_member_email_authentication(group, current_user) } )
        # go directly to the group page to entroll
        redirect_to_group(group, @authentication)
      else # if not the invited user - new login is required
        flash[:error] = "Already logged in as another user"
      end
    when request.post?
      # to force for testing, Settings.require_activation = true
      begin
        @user.save!
        flash[:notice] = "Thanks for signing up!"
        flash[:notice] << "<br />"
        flash[:notice] << "A confirmation has been sent to: #{@user.email}"
        logger.info("signed-up user: #{@user.inspect()}")
        sign_up_succeeded_p = true
      rescue SystemCallError, Net::SMTPError, Timeout::Error, IOError
        flash[:error] = "Unable to mail to: #{@user.email}"
        flash[:error] << "<br />"
        flash[:error] << "Due to exception: #{$!}"
        logger.warn("signup exception: #{$!}")
      rescue Exception
        flash[:error] = "Unable to complete sign up: #{$!}"
        logger.warn("signup exception: #{$!}")
      end

      # no  activation required, effect login to check password
      if ( sign_up_succeeded_p &&
           self.current_user = User.authenticate(@user.login, @user.password) )
        # activate user, and redirect to their home page
        redirect_to_group(group, @authentication)
      else
        render :action => 'signup_to_group'
      end
    end
  end
  
 
  def logout
    # puts("account_controller.logout()")
    # puts("account_controller.logout(): " + (logged_in?() ? current_user.login() : "?"))
    logger.info("logout(): " + (logged_in?() ? current_user.login() : "?"))
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token if cookies
    # puts("session before: [" +session.inspect() +"]")
    reset_session if session
    # puts("session after: [" +session.inspect() +"]")
    flash[:notice] = "You are now logged out."
    redirect_back_or_default(home_url)
  end
  
  def activate
    if logged_in?
      redirect_to(home_url)
    else
      @user = User.find_by_activation_code(params[:id])
      logger.info("to activate: user: #{@user}")
      if @user
        @user.activate! # observed to always return false/nil
        if (@user.current_state == :active)
          self.current_user = @user
          flash[:notice] = "Your account has been activated."
          redirect_to(:controller => 'users', :action => 'show',
                      :user_id => current_user.id())
          logger.info("activated: user: #{@user}")
      
        else
          redirect_to signup_url
        end
      else
        redirect_to signup_url
      end
    end
  end

  def instance_page_title()
    "Account - #{super()}"
  end

  def breadcrumb_trail
    trail = [ ['Home', home_url] ]
    case action_name.to_sym
    when :login
      trail << 'Login'
    when :signup
      trail << 'Signup'
    end
  end
  
  protected
  
  def permission_denied
    logger.info("[authentication] Permission denied to %s at %s for %s" %
      [(logged_in? ? current_user.login : 'guest'), Time.now, request.request_uri])
    redirect_to login_url
    return false
  end
end
