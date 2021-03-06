#!ruby
#
# Word Count Journal controller for users
# 
# 2006-11-17  james.anderson  rss
# 2006-11-18  james.anderson  find!; admin only for destroy
# 2006-11-19  james.anderson  logging
# 2006-11-20  james.anderson  (WCJ-AUS-F01 WCJ-AUS-F02) added restrict_access
# 2006-12-05  james.anderson  added if_specified? contraints to sidebars which depend on the user

VERSIONS[__FILE__] = "$Id: users_controller.rb 890 2007-11-18 20:08:54Z alex $"

class UsersController < ApplicationController
  SERVER_TIME_ZONE = TzinfoTimezone[$INITIAL_UTC_OFFSET].name
  DEFAULT_ATTRIBUTES = HashWithIndifferentAccess.new(:scope=> User::SCOPE_PUBLIC,
                                                     :description=> "",
                                                     :time_zone=> 'UTC')
  UPDATE_ATTRIBUTE_NAMES = [:first_name, :last_name, :email, :scope, :description,
                            :avatar_temp, :avatar, :time_zone, :login, :password, :password_confirmation]
  CREATE_ATTRIBUTE_NAMES = [:first_name, :last_name, :email, :scope, :description,
                            :avatar_temp, :avatar, :time_zone, :login, :password, :password_confirmation]
  SESSION_PARAMS = [['page', 'user_page'], ['page_size', 'user_page_size'],
                    'user_page', 'user_page_size']
  # puts("DEFAULT_ATTRIBUTES: #{DEFAULT_ATTRIBUTES.inspect}")
  @@rss_per_page = Settings.rss_per_page || 20;
  # @@html_per_page = Settings.html_per_page || 10;

  # access_rule 'admin', :only => [:activate, :suspend, :destroy]
  access_rule 'admin', :only => [:activate, :suspend]
  access_rule 'user' || 'admin', :only => [:assert, :deny, :destroy]

  before_filter :find_user!, :only => [:add_favorite, :activate, :assert, :change_password, :deny,
                                       :edit, :update, :destroy, :remove_favorite, :show, :suspend]
  before_filter :find_journal!, :only=> [:add_favorite, :remove_favorite]
  before_filter :restrict_read, :only=> [:show]
  before_filter :restrict_access,
                :only => [:activate, :add_favorite, :assert, :change_password, :deny, :destroy, :edit,
                          :remove_favorite, :suspend, :update]
  
  sidebar :user_profile, :if => :user_specified?, :except => [:index, :list, :new, :create, :edit, :update], :position => 'sidebar'
  sidebar :user_favorites, :if => :user_specified?, :only => [:show], :position => 'sidebar'
  sidebar :user_groups, :if => :user_specified?, :only => [:show], :position => 'sidebar'
  sidebar :user_change_password, :if => :logged_in?, :only => [:edit, :update], :position => 'sidebar'
  sidebar :user_destroy, :if => :logged_in?, :only => [:edit, :update], :position => 'sidebar'
  #sidebar :user_tools, :if => :user_is_current_user?, :only => [:show], :position => 'sidebar'
  #sidebar :invite_friends, :if => :user_is_current_user?, :only => [:show], :position => 'sidebar'

  #sidebar :find_entries, :only => [:show]
  #sidebar :friends, :if => :user_specified?, :only => [:show]
  
  sidebar :latest_entries, :only => [:show], :position => 'footer'
  sidebar :latest_photos, :only => [:show], :position => 'footer'
  sidebar :user_comments, :only => [:show], :position => 'footer'
  
  sidebar :latest_users, :only => :list, :position => 'footer'
  sidebar :latest_entries, :only => :list, :position => 'footer'
  sidebar :latest_comments, :only => :list, :position => 'footer'
  
  # class methods
  def self.filter_attributes(attributes= {},
                             names=UPDATE_ATTRIBUTE_NAMES,
                             defaults=DEFAULT_ATTRIBUTES)
    super(attributes, names, defaults)
  end
  
  
  # action methods
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :create, :update ],
         :redirect_to => { :action => :list }

  def list
    require_description = param(:require_description, false)
    require_avatar = param(:require_avatar, false)
#    @user_pages, @users =
#      (current_user_is_admin?() ?
#       paginate(:users, :order=> "updated_at DESC", :per_page => Settings.users_limit) :
#       paginate(:users, :conditions => [("state = ? AND scope = ?" +
#                                         (require_avatar ? " and avatar != ''" : "") +
#                                         (require_description ? " and description != ''" : "")),
#                                        'active', User::SCOPE_PUBLIC],
#                        :order=> "updated_at DESC",
#                        :per_page => Settings.users_limit))
  end

  # establish the state for presenting a single author
  # @user : the designated user
  # @group_pages, @groups : paginated extension scoped for that user
  # @journal_pages, @journals : paginated extension scoped for that user
  def show
    @groups = nil;
    @journals = nil;
    record_request(@user)
  end


  def new
    @user = User.new(DEFAULT_ATTRIBUTES)
  end

  def edit
  end

  def rss
    @users = User.find(:all, :limit=>@@rss_per_page, :order=>"last_name ASC, first_name ASC",
                             :conditions=>[ "scope=?", User::SCOPE_PUBLIC ])
    render(:layout => false)
  end


  # post actions
  
  def activate
    if (@user.current_state == :active)
      logger.info("[user #{current_user.id}] attempt to activate active user: #{@user.login}/#{@user.id}")
    else
      @user.activate!
      logger.info("[user #{current_user.id}] activated user: #{@user.login}/#{@user.id}")
    end
    redirect_to(:action=> 'show')
  end
  
  def add_favorite
    scope = params['scope']
    if scope == (begin
                    @user.add_favorite(@journal, scope)
                  rescue Exception
                    nil
                  end) 
      flash[:notice] = "This journal was successfully added to your favorites."
    else
      flash[:notice] = "Cannot add this journal to your favorites."
    end
    # someone used an old link w/o context
    # redirect_to :back
    redirect_back_or_default(:controller => 'users', :action => 'show', :user_id => @user.id)
  end
  
  # make an assertion for the user's current context
  #  {:subject=> {:type=> name, :text=> (text + id)},
  #   :predicate=> {:type=> name, :text=> (text + id)},
  #   :object=> {:type=> name, :text=> (text + id)} }
  #   
  def assert
    if ( (subject = intern_query_parameter(params[:subject])) &&
         (predicate = intern_query_parameter(params[:predicate])) &&
         (object = intern_query_parameter(params[:object])) )
      @assertion = current_user.assert(subject, predicate, object)
    end
    render_assertion_response(@assertion)
  end
  
  # change the users password and dispatch a notification #82
  # [:new_password] the new password
  # [:old_password] the old password
  # require old to match; encrypt, set new and save; dispatch a notification
  def change_password
    old_password = ((pw = params[:old_password]).kind_of?(String) && pw.length > 0 ? pw : nil)
    new_password = ((pw = params[:new_password]).kind_of?(String) && pw.length > 0 ? pw : nil)
    @error_message = ""
    if (old_password && new_password)
      if (@user.authenticated?(old_password))
        @user.password=(new_password)
        @user.password_confirmation=(params[:new_password_confirmation] || new_password)
        if (@user.save)
          @notice_message = 'Password was changed successfully.'
          UserNotifier.deliver_change_password(@user, current_user)
        else
          @error_message = 'Password could not be changed.<br />'
        end
      else
        @error_message = 'Old password is not correct.<br />'
        logger.warn("A password change failed. Login: #{@current_user.login}/#{current_user.id} User: #{@user.login}/#{@user.id}")
        # should the user receive an email regarding this,
        # even if (at least nominally) they tried to change it themself?
        unless (@user == current_user)
          UserNotifier.deliver_change_password_failed(@user, current_user)
        end
      end
    else
      @error_message = 'Please fill in both fields.<br />'
    end

    # otherwise
    @error_message << 'Password was not changed.' if @notice_message.blank?
    respond_to do |wants|
      wants.html {
        flash[:notice] = @notice_message
        flash[:error] = @error_message
        redirect_back_or_default(:controller => 'users', :action => 'edit', :user_id => current_user.id)
      }
      wants.js { @change_password_message = @notice_message || ( @error_message + " Please try again." )
        render(:partial=> 'sidebars/user_change_password')
      }
    end
  end
  
  def create
    raw_user_params = params[:user] || {}
    user_params = self.class.filter_attributes(raw_user_params, CREATE_ATTRIBUTE_NAMES)
    if (utc_offset_string = param('utc_offset', nil, params))
      utc_offset = Integer(utc_offset_string)
      time_zone = TzinfoTimezone[utc_offset].name
      user_params[:time_zone] = time_zone
    end
    @user = User.new(user_params)
    @user.contact_permissions_news = param(User::CONTACT_PERMISSIONS_NEWS, false, raw_user_params)
    
    if @user.save
      # stored out-of-line to user, so requires user id
      @user.overdue_reminders = param(User::OVERDUE_REMINDERS, false, raw_user_params)
      logger.info("user created: [params: #{user_params.inspect()}]: #{@user.inspect()}")
      flash[:notice] = 'User was successfully created.'
      redirect_to :action => 'list'
    else
      logger.warn("user create failed: [params: #{user_params.inspect()} ]: #{@user.errors.full_messages}")
      # puts("user create failed: [params: #{user_params.inspect()} ]: #{@user.errors.full_messages}")
      flash[:notice] = 'User not created.'
      render :action => 'new'
    end
  end

  def deny
    if ( (subject = intern_query_parameter(params[:subject])) &&
         (predicate = intern_query_parameter(params[:predicate])) &&
         (object = intern_query_parameter(params[:object])) )
      @assertion = current_user.deny(subject, predicate, object)
    end
    render_assertion_response(@assertion)   
  end

  def destroy
    logger.info("user to be removed: " + @user.inspect())
    # Change by Alex @ 2007-11-18
    # The soft deletion doesn't seem to work very well,
    # so let's properly delete the user.
    @user.destroy
    # @user.remove!
    
    # log the user out
    if (user_is_current_user?())
      logger.info("logout(): " + (logged_in?() ? current_user.login() : "?"))
      @current_user = nil
      cookies.delete :auth_token
      reset_session
      flash[:notice] = "Your account has been removed. You are now logged out. We are sorry to see you go."
    end
    redirect_to(home_url)
  end
  
  def remove_favorite
    @user.remove_favorite(@journal)
    flash[:notice] = "This journal was successfully removed from your favorites."
    redirect_to :back
  end

  def update
    raw_user_params = params[:user] || {}
    user_params = self.class.filter_attributes(raw_user_params, UPDATE_ATTRIBUTE_NAMES)
    @user.contact_permissions_news = param(User::CONTACT_PERMISSIONS_NEWS, false, raw_user_params)
    @user.overdue_reminders = param(User::OVERDUE_REMINDERS, false, raw_user_params)
    
    if @user.update_attributes(user_params)
      logger.info("user modified: [params: #{user_params.inspect()}]: #{@user.inspect()}]")
      flash[:notice] = user_is_current_user? ? 'Your profile was successfully updated.' : 'User was successfully updated.'
      redirect_to :action => 'show', :user_id => @user.id()
    else
      logger.warn("user update failed: [params: #{user_params.inspect()} ]: #{@user.errors.full_messages}")
      render :action => 'edit'
    end
  end

  def suspend
    if (@user.current_state == :suspended)
      logger.info("[user #{current_user.id}] attempt to suspend suspended user: #{@user.login}/#{@user.id}")
    else
      @user.suspend!
      logger.info("[user #{current_user.id}] suspended user: #{@user.login}/#{@user.id}")
    end
    redirect_to(:action=> 'show')
  end
  

  hide_action :breadcrumb_trail
  
  def instance_page_title()
    if @user
      "#{@user.login} - #{super()}"
    else
      super()
    end
  end
      

  # generate a breadcrumb for the current resource
  # the successive levels depend on the controller, the operation, and the requested resource.
  # a journals_controller recognizes
  #   :list :new :show
  #   :create :destroy :index :update : all redirect
  def breadcrumb_trail()
    trail = [ ['Home', home_url] ]
    if (@user && @user.active?)
      case (action_name.instance_of?(String) ? action_name.intern() : action_name)
      when :show
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << @user.login
      when :list
        trail << "People"
      when :new
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << 'New Person'
      when :edit
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << [@user.login, @user.url]
        trail << 'Edit'
      end
    else
      # was a list w/o a user
      trail << "People"
    end
    trail
  end

  # pagination for user presentation overrides the default page position with
  # :user_journal_page, but only if it is explicitly present,
  def compute_journal_pages(args = {})
    journal_page = param(:user_journal_page, 1, params())
    super({'journal_page'=> journal_page}.merge(args))
  end
  
  protected
  
  # compute entry sets in a user context
  def compute_entry_pages(args = params)
    if ( @user )
      Entry.with_scope(:find=> {:include=> [:journal],
                                :conditions=> ( (user_is_current_user?() || current_user_is_admin?() ) ?
                                                ["journals.user_id = ?", @user.id()] :
                                                ( @require_photo ?
                                                  ["journals.user_id = ? AND journals.scope = ? AND entries.state = ? AND entries.photo != ''",
                                                   @user.id(), User::SCOPE_PUBLIC, 'published'] :
                                                  ["journals.user_id = ? AND journals.scope = ? AND entries.state = ?",
                                                   @user.id(), User::SCOPE_PUBLIC, 'published']) ) }) {
        @entry_pages, @entries = paginate( :entries, :order => 'entries.updated_at DESC')
      }
    else
      super()
    end                                 
  end
  
  # used to determine whether to permit the current (possibly not authenticated) user access
  # to read a resource in the journal realm
  def restrict_read
    # puts("restrict_read: #{@user.scope}")
    # if no specific journal or the journal is public, ok for any request
    if (@user == nil || (@user.scope == User::SCOPE_PUBLIC))
      true
    # otherwise, require authentication
    else
      if (logged_in?)
        # do not restrict admins. otherwise both the owner and members of
        # a franchising group can read
        if (current_user_is_admin?() || (@user == current_user))
          true
        else
          permission_denied('list')
        end
      else
        permission_denied('list')
      end
    end
  end
  
  
  def restrict_access
    permission_denied unless (user_is_current_user?() || current_user_is_admin?())
  end
    
  def permission_denied(action = 'show')
    logger.info("[authentication] Permission denied to %s at %s for %s" %
      [(logged_in? ? current_user.login : 'guest'), Time.now, request.request_uri])
    flash[:error] = (logged_in? ? "You do not have access to this." : "That action requires that you first log in.")
    redirect_to(:action => action, :id => @user)
    return false
  end
  
  def update_contact_permissions_new(user, params)

    contact_permissions = user.contact_permissions;
    if contact_permissions_news
      unless user.contact_permissions.include?('news')
        user.contact_permissions << 'news'
      end
    else
      if user.contact_permissions.include?('news')
        user.contact_permissions.delete('news')
      end
    end
    user
  end

end
