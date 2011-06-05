#!ruby
#
# Word Count Journal controller for groups
# (c) 2006 makalumedia
# 
# 2006-11-18  james.anderson  find!
# 2006-11-19  james.anderson  logging
# 2006-11-20  james.anderson  (WCJ-ASC-F01 WCJ-ASC-F02) added is_admin? to restrict_access
# 2006-11-24  james.anderson  (WCJ-ACG-A03) add a member to any group which they create
# 2006-11-26  james.anderson  added entry_class (adresses #15)
# 2006-11-20  james.anderson  initialize new group's owner
# 2006-12-04  james.anderson  distinct restrict_read/write
# 2006-12-09  james.anderson  added user subscription/cancellation
# 2006-12-11  james.anderson  group invitation
#    action \ distinction:           authenticate      email url           logged_in to    finally to
#  invite_member                      by user_id     login_to_group        add_member      group page
#  invite_guest                       by email       signup_to_group       add_member      group page
# 2006-21-31  james.anderson  corrected compute_user_pages to return group members if group was specified.
#
# journals in a group:
# select g.id, j.id, g.title,j.title from groups g left join  groups_journals on groups_journals.group_id = g.id left join journals j on groups_journals.journal_id = j.id;

VERSIONS[__FILE__] = "$Id: groups_controller.rb 872 2007-04-10 16:59:14Z alex $"

require "entry_calendar_controller"

class GroupsController < ApplicationController
  include EntryCalendarController

  DEFAULT_ATTRIBUTES = HashWithIndifferentAccess.new(:scope=> User::SCOPE_PUBLIC)
  UPDATE_ATTRIBUTE_NAMES = [:title, :description, :state, :scope]
  CREATE_ATTRIBUTE_NAMES = [:title, :description, :state, :scope]
  SHOW_BREADCRUMB_SCOPE_IS_OWNER = false
  NEW_BREADCRUMB_SCOPE_IS_OWNER = true
  SESSION_PARAMS = [['page', 'group_page'], ['page_size', 'group_page_size'],
                    'entry_page', 'entry_page_size',
                    'group_page', 'group_page_size',
                    'journal_page', 'journal_page_size',
                    'user_page', 'user_page_size']
  @@rss_per_page = Settings.rss_per_page || 20;
  # @@html_per_page = Settings.html_per_page || 10;

  # access_rule 'admin', :only => [:destroy]
  access_rule 'user || admin', :only => [:add, :assert, :create, :deny, :edit, :new, :remove, :update,
                                         :invite_member, :invite_guest, :invite,
                                         :add_journal, :remove_journal,
                                         :add_member, # this will restrict guests
                                         :remove_member]
  # http://127.0.0.1:3000/users/1/groups/1/add_member?member_id=4&add_member=a271aaabe640a393a2f38fe92078471d0013fa9b
  before_filter :get_date, :only => [:show]
  before_filter :find_user!, :except => [:index, :list, :rss, :show, :list_sidebar]
  before_filter :find_user_if_specified!, :only=> [:list, :rss, :add, :remove]
  before_filter :find_journal_if_specified!, :only=> [:add, :list, :remove]
  before_filter :find_journal!, :only=> [:add_journal, :remove_journal]
  before_filter :find_member!, :only=> [:invite_member, :add_member, :remove_member]
  before_filter :find_member_if_specified!, :only=> [:add, :remove]
  before_filter :find_group!,
                :only => [:add, :add_journal, :add_member, :assert, :deny, :destroy, :edit,
                          :invite_guest, :invite_member, :invite,
                          :remove, :remove_member, :remove_member, :remove_journal, :show, :update]
  before_filter :restrict_read, :only=> [:show]
  # Only the owner of the group can modify it
  before_filter :restrict_write, :only => [:edit, :update, :destroy]
  # ensure that login and resource owner match unless admin
  # can't constrain for ad.remove as the authenticated user is not the owner.
  before_filter :restrict_identity, :only => [:new, :create] 

  sidebar :group_about, :only => :show, :position => 'sidebar'
  #sidebar :group_members, :if => :group_specified?, :only => :show, :position => 'sidebar'
  sidebar :group_management, :only => :show, :position => 'sidebar', :if => :logged_in?
  sidebar :group_invite, :only => :show, :position => 'sidebar', :if => :logged_in?
  #sidebar :group_subscribe, :only => :show, :if => :group_specified?, :position => 'sidebar'
  sidebar :group_destroy, :only => [:edit, :update], :if => :group_specified?, :position => 'sidebar'
  #sidebar :calendar, :only=> :show
  #sidebar :find_entries, :except => :index
  #sidebar :adsense_250x250, :only => [:show, :list], :position => 'sidebar'
  
  sidebar :group_your_groups, :only => :list, :position => 'sidebar', :if => :logged_in?
  sidebar :group_you_belong_to, :only => :list, :position => 'sidebar', :if => :logged_in?
  sidebar :latest_groups, :only => :list, :position => 'footer'
  sidebar :latest_entries, :only => :list, :position => 'footer'
  sidebar :latest_comments, :only => :list, :position => 'footer'
  
  def index
    list
    render :action => 'list'
  end

  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :index }

  # class methods
  def self.filter_attributes(attributes= {},
                             names=UPDATE_ATTRIBUTE_NAMES,
                             defaults=DEFAULT_ATTRIBUTES)
    super(attributes, names, defaults)
  end

  # GET actions
  def list
    # puts("list: params: #{params.merge(:if_does_not_exist => nil).inspect}")
    # if the user was provided, limit the retrieval scope.
    # puts("list: #{@user}")

#  superceded by collection methods
#    # puts("list: params: user:#{params[:user]}, journal: #{params[:journal]}")    
#    if (@user)
#      case
#      when ( current_user_is_admin? )
#        Group.with_scope(:find=> {:conditions=> [ 'user_id = ?', @user.id() ]}) {
#          @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit)
#          # puts("#{@user} groups: #{@groups}. [#{@user.inspect}]")
#        }
#      when ( logged_in? )
#        # allow for combination group x user member, not member, public, private
#        # puts("pagination based on logged in: #{@user.id}")
#        Group.with_scope(:find=> {:include=> [:users ],
#                                  :conditions=> ["groups.user_id = ? AND (groups.scope = ? OR groups_users.user_id = ?)",
#                                                 @user.id(), User::SCOPE_PUBLIC, current_user.id ]}) {
#          @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit)
#          # puts("#{@user} groups: #{@groups}. [#{@user.inspect}]")
#        }
#      else
#        Group.with_scope(:find=> {:conditions=> ['user_id = ? and scope = ?',
#                                                 @user.id(), User::SCOPE_PUBLIC ]}) {
#          @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit)
#          # puts("#{@user} groups: #{@groups}. [#{@user.inspect}]")
#        }
#      end
#    elsif (@journal)
#      case
#      when ( current_user_is_admin? )
#        @groups = @journal.groups
#      when ( logged_in? )
#        @groups = @journal.groups.find_all{|g| User::SCOPE_PUBLIC == g.scope || g.users.include?(current_user) }
#      else
#        @groups = @journal.groups.find_all{|g| User::SCOPE_PUBLIC == g.scope }
#      end
#      @group_pages = Paginator.new(self, @groups.length, [1, @groups.length].max, 1)
#    else
#      case
#      when ( current_user_is_admin? )
#        @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit )
#      when ( logged_in? )
#        Group.with_scope(:find=> {:include=> [:users ],
#                                  :conditions=> [ "groups.scope = ? OR groups_users.user_id = ?",
#                                                  User::SCOPE_PUBLIC, current_user.id ] }) {
#          @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit )
#        }
#      else
#        Group.with_scope(:find=> {:conditions=> [ "scope = ?", User::SCOPE_PUBLIC ] }) {
#          @group_pages, @groups = paginate(:groups, :per_page => Settings.group_limit )
#        }
#      end
#    end
    # puts("list: @user: #{@user}, @journal: #{@journal}")
    # puts("list: @groups: #{@groups}")
    # respond_to do |wants|
    #   wants.html
    #   wants.js
    # end
  end
  
  def list_sidebar
    list
    render :action => 'list', :layout => false
  end

  # establish the state for presenting a single group
  # @group : the designated group (filtered)
  # @users : author extension scoped for that group
  # @journals : journal extension scoped for that group
  # @entry_pages, @entries : paginated extension scoped for that group
  def show
    @journals = @group.journals
    unless @journals.blank?
      @users = @journals.map{ |journal| journal.owner(true) }
    end
    
    record_request(@group)
  end
  
  def new
    @group = Group.new(DEFAULT_ATTRIBUTES.merge(:owner=>@user))
  end

  def edit
  # puts("edit: group: " + @group.inspect())
  # puts("edit: description: " + @group.description().to_s())
  # @group.description=("a new value")
  # puts("edit: description: " + @group.description().to_s())
  end
  
  # 
  def invite
    email = params[:email]
    # logger.debug("group: #{@group}, group_id #{params[:group_id]},  email #{email.inspect}")
    if ( email.blank? )
      flash[:error] = "An email address is required."
    else
      flash[:error] = ""
      normalize_whitespace = /\s+/;
      email_addresses = email.gsub(normalize_whitespace,' ').split(' ')
      email_errors = email_addresses.reject{|address|
        mode = '?'
        begin
          if (address == current_user.email)
            flash[:error] << "#{address} is your email address. "
            false
          elsif (invite_user = User.find_by_login(address, :conditions=> [ "state = ? AND scope = ?",
                                                                           User::STATE_ACTIVE, User::SCOPE_PUBLIC ]))
            mode = :user_login
            (perform_user_invitation(@group, invite_user) ? true : false)
          elsif (address =~ AccountController::EMAIL_REGEX)
            if (invite_user = User.find_by_email(address, :conditions=> [ "state = ? AND scope = ?",
                                                                          User::STATE_ACTIVE, User::SCOPE_PUBLIC ]))
              mode = :user_email
              (perform_user_invitation(@group, invite_user) ? true : false)
            else
              mode = :guest_email
              perform_guest_invitation(@group, address)
              true
            end
          else
            flash[:error] << "#{address} serves neither for email, nor as a member name."
            false
          end
        rescue Exception
          logger.warn("invite: for '#{address}' (as #{mode}): email problem: #{$!}")
          false
        end
      }
      # puts("addresses: #{email_addresses.inspect}")
      # puts("errors: #{email_errors.inspect}")
      if (email_errors.length == 0)
        flash[:notice] = "All inviations sent."
      else
        flash[:error] << "Invitations could not be sent to the following:<ul>"
        email_errors.map{|email| flash[:error] << "<li>#{email}</li>"}
        flash[:error] << "</ul>"
        @email = email_errors.join("\n")
        # puts("failed email: #{@email}")
      end
    end
    redirect_to :back
  end
  
  # invite a site user to enroll into a group
  def invite_member
    perform_user_invitation(@group, @member)
    flash[:notice] = "An invitation has been sent to #{@member.email}."
    redirect_to(:action=> 'show', :user_id=> @user.id, :group_id=> @group.id)
  end
 
  # invite a site guest to enroll in a group
  def invite_guest
    # puts("invite_guest: group: #{@group}, user: #{@user}, member: #{@member}")
    # bind for tests
    email = params[:email]
    if ( !(email.blank?) )
      perform_guest_invitation(@group, email)
      flash[:notice] = "An invitation has been sent to #{email}."
    else
      flash[:error] = "An email address is required."
    end
    redirect_to(:action=> 'show', :user_id=> @user.id, :group_id=> @group.id)
  end

  def rss
    # retrieve by update date - could be delegated comment date
    @groups = Group.find(:all, :limit=>@@rss_per_page, :order=>"updated_at DESC",
                         :conditions=>[ "scope=?", User::SCOPE_PUBLIC ])
    
    render(:layout => false)
  end
  

  # POST actions

  # franchise a journal to a group or add a member
  # restricted to a journal which the current user owns
  def add
    case
    when @journal
      add_journal()
    when @member
      add_member()
    else
      flash[:notice] = "An addition requires either a member or a journal."
      redirect_to(:action=> 'show')
    end
  end
  
  # add a member user to the group
  # require that the groupd be public, or the request contain the proper credentials.
  # authentication is by member id if the invite was to an existing site user, but
  # by email, if the invite was to a user who needed firt to join the site.
  def add_member
    # puts("current_user: #{current_user.id}")
    # puts("add authentication params: #{params[:add_member]}")
    # puts("add authentication intern: #{add_member_user_authentication(@group, @member)}")
    # puts("current_user == @member: #{current_user == @member}")
    # puts("authenticated?: #{authenticated?(params[:add_member]){ || add_member_user_authentication(@group, @member) }}")
    if (current_user_is_admin?() ||
        (current_user == @member &&
         ( @group.is_public?() ||
           authenticated?(params[:add_member]){ || add_member_user_authentication(@group, @member) } ||
           authenticated?(params[:add_member]){ || add_member_email_authentication(@group, @member.email) })))
      if ( @group.users.include? @member )
        flash[:error] = 'User is already enrolled. Group was not modified.'
      else
           @group.users << @member
        if (@group.save && @member.save)
          logger.info("[#{current_user.login}/#{current_user.id}] user added to group: [params: #{params.inspect()}]")
          flash[:notice] = 'User was successfully subscribed.'
        else
          flash[:error] = 'Group was not modified.'
        end
      end
    else
      flash[:error] = 'Group does not permit access.'
    end
  redirect_to(:action=> 'show', :user_id=> @user.id, :group_id=> @group.id)
  end
  
  def add_journal
    # puts("add_journal: #{current_user_is_admin?()}")
    # puts("add_journal: #{(@group.scope == User::SCOPE_PUBLIC)}")
    # puts("add_journal: #{(@group.owner == current_user() && @journal.owner == current_user())}")
    # puts("add_journal: members: #{@group.users}")
    if (current_user_is_admin?() ||
        (@group.is_public?) ||
        (@group.owner == current_user() && @journal.owner == current_user()))
      @group.journals << @journal
      if (@group.save && @journal.save)
        logger.info("[#{current_user.login}/#{current_user.id}] journal franchised: [params: #{params.inspect()}]")
        flash[:notice] = 'Journal was successfully franchised.'
      else
        flash[:error] = 'Group was not modified.'
      end
    else
      flash[:error] = 'Group does not permit access.'
    end
    # puts("redirecting=> #{url_for(:action => 'show', :group_id=>@group.id)}.")
    redirect_to :action => 'show', :group_id=>@group.id
  end

  # make an assertion in the group's current context 
  #  {:subject=> {:type=> name, :text=> (text + id)},
  #   :predicate=> {:type=> name, :text=> (text + id)},
  #   :object=> {:type=> name, :text=> (text + id)} }
  #   
  def assert
    if ( (subject = intern_query_parameter(params[:subject])) &&
         (predicate = intern_query_parameter(params[:predicate]))&&
         (object = intern_query_parameter(params[:object])) )
        @assertion = @group.assert(subject, predicate, object)
    end
    render_assertion_response(@assertion)   
  end
  
  def create()
    create_params = self.class.filter_attributes(params[:group], CREATE_ATTRIBUTE_NAMES)
    @group = Group.new(create_params)
    @group.owner = @user
    @group.users << @user
    if @group.save()
      logger.info("[#{current_user.login}/#{current_user.id}] group created: [params: #{create_params.inspect()}]: #{@group.inspect()}")
      flash[:notice] = 'Group was successfully created. Invite people to join your new group.'
      redirect_to @group.url_hash.merge(:action => 'show')
    else
      logger.warn("group create failed: [params: #{create_params.inspect()} ]: #{@group.errors.full_messages}")
      flash[:error] = 'Group was not created.'
      render :action => 'new'
    end
  end

  def deny
    if ( (subject = intern_query_parameter(params[:subject])) &&
         (predicate = intern_query_parameter(params[:predicate])) &&
         (object = intern_query_parameter(params[:object])) )
      @assertion = @group.deny(subject, predicate, object)
    end
    render_assertion_response(@assertion)
  end

  def destroy
    logger.info("group to be removed: " + @group.inspect())
    @group.remove!
    # redirect_to :action => 'list'
    redirect_to :controller =>"users", :action => 'show',
                :user_id=>@user.id()
  end
  
  # remove a specified journal or user from the group
  def remove
    case
    when @journal
      remove_journal()
    when @user
      remove_member()
    else
      redirect_to(:action=> 'show')
    end
  end
  
  def remove_journal
    if (current_user_is_admin?() || user_is_current_user?(@group.owner) ||
        user_is_current_user?(@journal.owner))
      @group.journals.delete(@journal)
      if (@group.save && @journal.save)
        logger.info("[#{current_user.login}/#{current_user.id}] journal retracted: [params: #{params.inspect()}]: #{@journal.inspect()}")
        flash[:notice] = 'Journal was successfully retracted.'
      else
        flash[:error] = 'Group was not modified.'
      end
    else
      flash[:error] = 'Group was not modified.'
    end
    redirect_to :action => 'show', :group_id=> @group.id, :user_id=> @user.id
  end
  
  def remove_member
    flash[:notice] = nil
    flash[:error] = nil
    if (current_user_is_admin?() || @group.owner == current_user() || current_user == @member)
      @member.journals.each{|j|
        if @group.journals.include?(j)
          @group.journals.delete(j)
        end
      }
      @group.users.delete(@member)
      if (@group.save && @member.save)
        logger.info("user membership rescinded: [params: #{params.inspect()}]: #{@member.inspect()}")
        flash[:notice] = 'You have successfully left the group.'
        redirect_to :action => 'list'
      else
        flash[:error] = 'Group was not modified.'
        redirect_to :action => 'show', :group_id=> @group.id, :user_id=> @user.id
      end
    else
      flash[:error] = 'Group does not permit access.'
      redirect_to :action => 'list'
    end
  end
  
  
  def update()
    group_params = self.class.filter_attributes(params[:group], UPDATE_ATTRIBUTE_NAMES)
    logger.debug("update: form attributes: #{params[:group].inspect()} filtered to: #{group_params.inspect()}")
  
    if @group.update_attributes(group_params)
      logger.info("group modified: [params: #{group_params.inspect()} ]: #{@group.inspect()}")
      flash[:notice] = 'Group was successfully updated.'
      redirect_to :action => 'show', :group_id => @group.id()
    else
      logger.warn("group update failed: [params: #{group_params.inspect()} ]: #{@group.errors.full_messages}")
      render :action => 'edit'
    end
  end

  
  hide_action :breadcrumb_trail, :entry_class, :user, :journal,
              :authenticated?, :add_member_email_authentication, :add_member_user_authentication  
  helper_method :user, :journal

  def instance_page_title()
    if (@group && @group.active?)
      "#{@group.owner.login} - [#{@group.title}] - #{super()}"
    elsif (@user && @user.active?)
      "#{@user.login} - Groups - #{super()}"
    else
      super()
    end
  end
      
  # interface accessors

  def user()
    @user
  end
  
  def journal()
    @journal
  end
  
  # generate a breadcrumb for the current resource
  # the successive levels depend on the controller, the operation, and the requested resource.
  # a journals_controller recognizes
  #   :list :new :show
  #   :create :destroy :index :update : all redirect
  def breadcrumb_trail()
    trail = [ ['Home', home_url] ]
    if (@group && @group.active?)
      case (action_name.instance_of?(String) ? action_name.intern() : action_name)
      when :show
        list_url = (SHOW_BREADCRUMB_SCOPE_IS_OWNER ?
                    owned_groups_url(:controller=> "groups", :action=> :list, :user_id=> @group.owner.id) :
                    {:controller=> "groups", :action=> :list})
        trail << ["Groups", list_url]
        trail << @group.title
      when :list
        trail << "Groups"
      when :new
        list_url = (NEW_BREADCRUMB_SCOPE_IS_OWNER ?
                    owned_groups_url(:controller=> "groups", :action=> :list, :user_id=> @group.owner.id) :
                    {:controller=> "groups", :action=> :list})
        trail << ["Groups", list_url]
        trail << [@group.owner.name, @group.owner.url]
      end
    else
      # was a list w/o a group
      trail << "Groups"
    end
    trail
  end
  
  def entry_class(date, context_params = {})
    if (@group)
      context_entry_class(date, {:group=> @group}.merge(context_params))
    else
      ENTRY_CLASS_OK
    end
  end
  
  # an operation is authenticated by accompanying it with a operation-specific password.
  # this function accepts the encrypted password and either a literal original,
  # or a closure which returns one.
  def self.authenticated?(token, data=nil)
    ( token ?
      token == (data ? data : ( block_given? ? yield : "") ) :
      false )
  end
  def authenticated?(token, data=nil)
    if (block_given?)
      self.class.authenticated?(token, data){|| yield }
    else
      self.class.authenticated?(token, data)
    end
  end
  
  def self.add_member_user_authentication(group, user)
    User::encrypt("<authentication user='#{user.id}' group='#{group.id}' action='add_member'/>")
  end
  def add_member_user_authentication(group, user)
    self.class.add_member_user_authentication(group, user)
  end
  def self.add_member_email_authentication(group, email)
    User::encrypt("<authentication email='#{email}' group='#{group.id}' action='add_member'/>")
  end
  def add_member_email_authentication(group, email)
    self.class.add_member_email_authentication(group, email)
  end
  
  protected
  
  # differs from the global in that prioroty is given to group constituency
  def compute_entry_pages(args = {})
    page_size = session_param([:entry_page_size, :page_size], Settings.entry_limit, args) || Entry.count
    page_number = session_param([:entry_page, :page], 1, args) # not used
    conditions = []
    offset = (page_number - 1) * page_size
    owner = (@group ? @group.owner : nil)
    entry_sort = (presentation_setting((@journal || Entry), :entry_sort, [args, session, current_user, @group, owner, site_context()]) || {})
    sort_column = entry_sort['column'] || 'date'
    sort_order = entry_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "e.#{@page_sort_order['column']} #{@page_sort_order['order']}"

    if (param(:group, nil, args))
      if (@group && @group.journals.length > 0)
        if ( current_user_is_admin?() )
          journal_ids = @group.journals.map{ |journal| journal.id() }.compact
          @entries = Entry.find_by_sql(conditions = ["SELECT SQL_CALC_FOUND_ROWS e.* FROM entries e WHERE e.journal_id in (?) LIMIT #{offset}, #{page_size} ORDER #{order_option}",
                                                     journal_ids] )
        else
          journal_ids = @group.journals.find_all{ |journal| journal.active? }.collect{|j| j.id}
          @entries = Entry.find_by_sql(conditions = ["SELECT SQL_CALC_FOUND_ROWS e* FROM entries e WHERE e.journal_id in (?) AND e.state = ? LIMIT #{offset}, #{page_size} ORDER #{order_option}",
                                                     journal_ids, 'published'] )
        end
        extent_count = Entry.count_by_sql('SELECT FOUND_ROWS()')
      else
        @entries = []
        extent_count = 0
      end
      @entry_pages = Paginator.new(self, extent_count, [page_size, @entries.length].max, page_number)
      logger.debug("GC#c_e_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} group: #{@group ? @group.id : '-'}")
      logger.debug("GC#c_e_p: ? [#{conditions.join(' ')}]")
      logger.debug("GC#c_e_p: = [#{@entries.map{|i| i.id.to_s}.join(',')}]/#{@entry_pages.page_count}/#{@entry_pages.item_count}")
    else
      logger.debug("GC#c_e_p->super()")
      super()
    end
    
  end
   
  # differs from the global in that prioroty is given to group constituency
  # if a group was specified, collect its journals.
  # if it was specified, but not found, then the journal set is empty
  # if no group was specified, delegate to  compute the global collection
  # nb. when the constituency grows, this will need to be paginated for real
  def compute_journal_pages(args = {})
    page_size = session_param([:group_journal_page_size, :page_size], Settings.journal_limit, args) || Journal.count
    page_number = session_param([:group_journal_page, :page], 1, args)
    offset = (page_number - 1) * page_size
    conditions = []
    journal_sort = (presentation_setting(Journal, :journal_sort, [args, session, current_user, @group, site_context()]) || {})
    sort_column = journal_sort['column'] || 'updated_at'
    sort_order = journal_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "journals.#{@page_sort_order['column']} #{@page_sort_order['order']}"
   
    if (param(:group_id, nil, args) || param(:id, nil, args))
      if (@group)
        @journals = (current_user_is_admin?() ?
                     Journal.find(:all, :limit => page_size,
                                        :include => ['groups'],
                                        :conditions => (conditions = [ "groups.id = ?", @group.id ]),
                                        :offset=> (page_number - 1) * page_size,
                                        :select=> "SQL_CALC_FOUND_ROWS *",
                                        :order => order_option) :
                     Journal.find(:all, :limit => page_size,
                                        :include => ['groups'],
                                        :offset=> (page_number - 1) * page_size,
                                        :conditions => (conditions = [ "groups.id = ? AND journals.state=?", @group.id, Journal::STATE_ACTIVE ]),
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => order_option) )
        # Dirty hack but what'cha gonna do... --Alex B--
        extent_count = (current_user_is_admin?() ?
                     Journal.count(:all,:include => ['groups'],
                                        :conditions => (conditions = [ "groups.id = ?", @group.id ]),
                                        :select=> "SQL_CALC_FOUND_ROWS *",
                                        :order => order_option) :
                     Journal.count(:all,:include => ['groups'],
                                        :conditions => (conditions = [ "groups.id = ? AND journals.state=?", @group.id, Journal::STATE_ACTIVE ]),
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => order_option) )
      else
        @journals = []
        extent_count = 0
      end
      @journal_pages =
        Paginator.new(self, extent_count, [page_size, @journals.length].max, page_number)
      logger.info("GC#c_j_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} group: #{@group ? @group.id : '-'}")
      logger.info("GC#c_j_p: ? [#{conditions.join(' ')}] x #{order_option}")
      logger.info("GC#c_j_p: = [#{@journals.map{|i| i.id.to_s}.join(',')}]/#{@journal_pages.page_count}/#{@journal_pages.item_count}")
    else
      logger.debug("GC#c_j_p->super()")
      super()
    end
  end
  
  # if a group was specified, collect its journals.
  # if it was specified, but not found, then the set is empty.
  # otherwise, delegate to compute the global collection
  # nb. when the constituency grows, this will need to be paginated for real
  def compute_user_pages(args = params)
    page_size = param([:user_page_size, :page_size], Settings.user_limit, args) || User.count
    page_number = param([:user_page, :page], 1, args) # not used

    if (param(:group, nil, args))
      if (@group)
        @users = (current_user_is_admin?() ?
                  @group.users :
                  @group.users.find_all{ |user| user.active? })
      else
        @users = []
      end
      @user_pages =
        Paginator.new(self, @users.length, [page_size, @users.length].max, page_number)
      logger.debug("GC#c_u_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} group: #{@group ? @group.id : '-'}")
      logger.debug("GC#c_u_p: = [#{@users.map{|i| i.id.to_s}.join(',')}]/#{@user_pages.page_count}/#{@user_pages.item_count}")
    else
      logger.debug("GC#c_u_p->super()")
      super()
    end
  end
 
  def perform_guest_invitation(group, email)
    # instance variable for debugging
    @authentication = add_member_email_authentication(group, email)
    
    # puts("authentication: (group x email) #{@authentication}")
    email_user = User.new(:email=> email)
    UserNotifier.deliver_group_email_invitation(group, email_user, @authentication)
    UserNotifier.deliver_group_invitation_reminder(group, email_user, current_user)
    unless (current_user == group.owner)
      UserNotifier.deliver_group_invitation_reminder(group, email_user, group.owner)
    end
    logger.info("[#{current_user.login}/#{current_user.id}] invited #{email} to join group '#{group.title}'/#{group.id}]")
    email
  end
  
  def perform_user_invitation(group, email_user)
    # instance variable for debugging
    if (email_user.active?)
      @authentication = add_member_user_authentication(group, email_user)
      UserNotifier.deliver_group_user_invitation(group, email_user, @authentication)
      UserNotifier.deliver_group_invitation_reminder(group, email_user, current_user)
      unless (current_user == group.owner)
        UserNotifier.deliver_group_invitation_reminder(group, email_user, group.owner)
      end
      logger.info("[#{current_user.login}/#{current_user.id}] invited #{email_user.email} to join group '#{group.title}'/#{group.id}]")
      email_user
    else
      nil
    end
  end
  
  
  # bind a date for use with the calendar when :show
  def get_date
    @date = users_today()
  end
    
  # used to determine whether to permit the current (authenticated) user access
  # to read the designated journal.
  # - admin users are always allowed
  # - non-group-specific lists will limit to public instances
  # - the user can be the group owner
  # - the group can be public
  # - the user can be in the group
  def restrict_read
    if (logged_in?)
      if (current_user.is_admin?() ||
          (@group == nil) ||
          (@group.owner == current_user) ||
          (@group.scope == User::SCOPE_PUBLIC) ||
          @group.users.include?(current_user))
        true
      else
        logger.warn("[authentication] Read restriction applied.")
        permission_denied('list')
      end
    else
      logger.warn("[authentication] Read restriction applied.")
      permission_denied('list')
    end
  end

  # used to determine whether to permit the current (possibly not authenticated) user access
  # to read a group
  def restrict_read
    if (@group == nil || (@group.scope == Group::SCOPE_PUBLIC))
      true
    # otherwise, require authentication
    else
      if (logged_in?)
        # do not restrict admins. otherwise both the owner and members of
        # a franchising group can read
        if (current_user_is_admin?() ||
            (@group.owner == current_user) ||
            (@group.users.include?(current_user)))
          true
        else
          permission_denied('list')
        end
      else
        permission_denied('list')
      end
    end
  end

  # used to determine whether to permit the current (authenticated) user access
  # to the designated group. admin users are always allowed, otherwise the
  # user must be the group owner
  def restrict_write
    # puts("group::restrict_write: " + @user.inspect())
    # puts("group::restrict_write: " + @group.inspect())
    # puts("restrict_write: " + @group.owner.inspect() + "==" + current_user.inspect() +
    #                           "admin?: " + current_user_is_admin?.to_s)
    unless (current_user_is_admin?() || (@group && @group.owner == current_user))
      logger.warn("[authentication] Write restriction applied.")
      permission_denied()
    end
  end

  # used to determine whether to permit the current (authenticated) user access
  # to act as the designated user. admin users are always alloed. otherwise the user
  # must be the designated user
  # todo: may be generalizable to application_controller
  def restrict_identity
    unless (current_user_is_admin?() || user_is_current_user?())
      logger.warn("[authentication] Identity restriction applied.")
      permission_denied()
    end
  end
  
  def permission_denied(action = 'show')
    logger.warn("[authentication] Permission denied to %s at %s for %s" %
      [(logged_in? ? current_user.login : 'guest'), Time.now, request.request_uri])
    flash[:error] = (logged_in? ? "You do not have access to this." : "That action requires that you first log in.")
    redirect_to( :action => action)
    return false
  end
  
  def find_member!(args = params)
    begin
      @member = find_user(:user_id => args[:member_id])
    rescue User::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:member_not_found, :status=>"404 Not Found")
      false
    end
  end

  def find_member_if_specified!(args = params)
    if ( args[:member_id] )
      find_member!(args)
    end
  end

end
