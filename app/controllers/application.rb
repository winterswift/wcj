#!ruby
#
# Word Count Journal abstract application controller
# 
# 2006-11-19  james.anderson  delegating find and find!
# 2006-11-20  james.anderson  added rescue blocks and 404 generation to
#  find! operators; recognized current_user as default in find_user!
# 2006-11-28  james.anderson  ArgumentError handlers now redirect to 404;
#   added _if_specified! and _specified? methods for use as/with filters
# 2006-12-06  james.anderson correct find_*! to return false after the 404 render
#   when the argument is not specified.
# 2006-12-14  james.anderson  optional parameter to user_is_current_user?
# 2006-12-23  james.anderson  complete entries/groups/journals/users accessors
# 2007-04-19  james.anderson  adjusted intern_param_value to allow '0'-prefixed integers
# 

require "annotation"

VERSIONS[__FILE__] = "$Id: application.rb 875 2007-04-19 06:15:10Z james $"

ASSERTION_CLASS_MAP = {'User' => User, 'Group'=> Group, 'Journal'=> Journal,
                       'Entry' => Entry}
                       
# cache site instance counts with updates on-demand at 5-minute intervals
$SITE_STATISTICS = nil
$SITE_STATISTICS_INTERVAL = 300
$PAGE_NUMBERS_ARE_PERSISTENT = false

# couldn't see any other way to init the constants and table with a default and contents
# as a single assignment expression
# 
$SORT_COLUMN_MAP ||=
  begin
    COLUMN_CREATED_AT = :created_at
    COLUMN_DATE = :date
    COLUMN_NAME = :name
    COLUMN_UPDATED_AT = :updated_at
    COLUMN_TITLE = :title
  
    map = {'date'=> COLUMN_DATE,
           'created'=> COLUMN_CREATED_AT, 'created_at'=>COLUMN_CREATED_AT,
           'name'=> COLUMN_NAME,
           'updated'=> COLUMN_UPDATED_AT, 'updated_at'=> COLUMN_UPDATED_AT,
           'title'=> COLUMN_TITLE }
    map.default=(COLUMN_UPDATED_AT)
    map
  end

$SORT_ORDER_MAP ||=
  begin
    SORT_ASCENDING = :asc
    SORT_DESCENDING = :desc
    map =  {'ascending'=> SORT_ASCENDING, 'asc'=> SORT_ASCENDING, '<'=> SORT_ASCENDING,
            'descending'=> SORT_DESCENDING, 'desc'=> SORT_DESCENDING, 'dsc'=> SORT_DESCENDING,
            '>'=> SORT_DESCENDING}
    map.default=(SORT_DESCENDING)
    map
  end

module SettingsSession
  # sessions combine an internal cache with delegated resolution
  # they first attempt to resolve internally based on the reference instance.
  # if they succeed they return that result. if they do not bind a result,
  # they delegate. if that succeeds, they cache that result for both instance 
  # and type and return it.
  # if the instance-specific delegation does not succeed, the process repeats
  # with the respective resource subject type, returning and caching as before.
  def context_setting(controller, subject, setting_name, rest, &continue)
    # puts("context_setting: #{controller}, #{subject}, #{setting_name}, #{rest}")
    # first, try to find a resource-specific setting
    if (subject.kind_of?(ActiveRecord::Base))
      key = "#{subject.class.name}/#{subject.id}"
      # puts("id-subject: #{key}: params: #{controller.params.inspect}")
      case
      # if the request specifies a value, use it and cache it for future
      # presentations for this resource and its type
      when (value = controller.params[setting_name])
        (self[key] ||= {})[setting_name] = value
        (self[subject.class.name.to_s] ||= {})[setting_name] = value
        return (value)
      # if a past setting exists for the specific resource,
      # the use it.
      when ((cache = self[key]) && value = cache[setting_name])
        return (value)
      # if delegation yields a value, use it and cache it for future
      # presentations for this resource and its type
      when (value = continue.call(subject, setting_name, rest))
        (self[key] ||= {})[setting_name] = value
        (self[subject.class.name.to_s] ||= {})[setting_name] = value
        return (value)
      # otherwise, replace the subject with its class and continue below, to
      # look for a general setting
      else
        subject = subject.class.name.to_s
      end
    end
    
    # if subject was specified as general, or if the specific search failed,
    # attempt to locate a setting for the class.
    # perform delegated search first, in order that general settings which are
    # associated with the resource supercede general settings from previous
    # resources
    # puts("context_setting:... by general #{subject}")
    if (subject.kind_of?(String))
      if (value = continue.call(subject, setting_name, rest))
        (self[subject] ||= {})[setting_name] = value
        # puts("context_setting:... found delegated")
        value
      elsif ((cache = self[subject]) && value = cache[setting_name])
        # puts("context_setting:... found cached")
        value
      end
    else
      nil
    end
  end
end

class CGI  # patch session to act more like hash
  class Session
    include SettingsSession
    def has_key?(key)
      @data ||= @dbman.restore
      @data.has_key?(key)    
    end
    
    def fetch(key, default = nil)
      @data ||= @dbman.restore
      @data.fetch(key, default)    
    end
  end
end

module ActionController
  class TestSession
    include SettingsSession
    def has_key?(key)
      @attributes.has_key?(key)    
    end
    
    def fetch(key, default = nil)
      @attributes.fetch(key, default)    
    end
  end
end

class Hash
  def context_setting(controller, subject, setting_name, rest, &continue)
    # first, a local search with the name string (was already coerced) and interned symbol
    self[setting_name] || self[setting_name.to_sym] ||
    continue.call(subject, setting_name, rest)
  end
end
  
module Annotation::Annotator
  def context_setting(controller, subject, setting_name, rest, &continue)
    # puts("Annotator.presentation_setting: [#{self.class.name}/#{self.id}.(#{subject} #{setting_name.inspect})]")
    if (subject.kind_of?(Annotation::Annotatable))
      if (value = asserted(subject, setting_name))
        # puts("by annotatable asserted: [#{self.class.name}/#{self.id}.(#{subject.class.name}/#{subject.id} #{setting_name.inspect})] #{value}.")
        value
      elsif (value = continue.call(subject, setting_name, rest))
        # puts("by annotatable continued: [#{self.class.name}/#{self.id}.(#{subject.class.name}/#{subject.id} #{setting_name.inspect})] #{value}.")
        value
      end
    else
      if (value = continue.call(subject, setting_name, rest))
        # puts("by type continued: [#{self.class.name}/#{self.id}.(#{subject.inspect} #{setting_name.inspect})#{value}.")
        value
      elsif (value = asserted(subject, setting_name))
        # puts("by type asserted: [#{self.class.name}/#{self.id}.(#{subject.inspect} #{setting_name.inspect})#{value}.")
        value
      end
    end
  end
end

class Annotation::Context
  def context_setting(controller, subject, setting_name, rest, &continue)
    if (subject.kind_of?(Annotation::Annotatable))
      if ((assertion = assertion_that(subject, setting_name)) &&
          (value = assertion.object))
        value
      else
        continue.call(subject, setting_name, rest)
      end
    else
      if (value = continue.call(subject, setting_name, rest))
        value
      elsif ((assertion = assertion_that(subject, setting_name)) &&
             (value = assertion.object))
         value
      else
        nil
      end
    end
  end
end
   

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include AuthenticatedSystem
  include Annotation::Examiner
  
  DEFAULT_ATTRIBUTES = {}
  DELETE_ATTRIBUTE_NAMES = ['id']
  CURRENT_USER_IS_DEFAULT_USER = false;  
  SESSION_PARAMS = ['page', 'page_size']
  
  # @@index_comment_limit = Settings.comment_limit || 5;
  # @@index_entry_limit = Settings.entry_limit || 5;
  # @@index_group_limit = Settings.group_limit || 5;
  # @@index_journal_limit = Settings.journal_limit || 5;
  # @@index_photo_limit = Settings.photo_limit || 8;
  # @@index_user_limit = Settings.user_limit || 5;
  
  @@require_description = Settings.require_description || true;
  @@require_avatar = Settings.require_avatar || true;
  @@require_photo = Settings.require_photo || true;
  @@entry_order = :date
  
  layout 'public'
  
  before_filter :login_from_cookie
  before_filter :cook_params
  #before_filter :default_to_guest
  #
  # class methods
  def self.filter_attributes(attributes= {}, names = [], defaults ={})
    attributes = defaults.merge(attributes || {})
    attributes.delete_if{|name, value| !(names.include?(name.to_sym)) }
    attributes
  end
  

  hide_action :breadcrumb_trail, :format_time, :users_today, :photos, :fully_qualified_domain_name
  hide_action :instance_page_title, :site_statistics, :feed_settings, :setting
  hide_action :user_is_current_user?, :current_user_is_admin?
  hide_action :entries, :entry_pages, :groups, :group_pages, :journals, :journal_pages
  hide_action :users, :user_pages, :comments, :comments_pages
  hide_action :page_sort_order, :compute_setting
  hide_action :site_journal, :site_entries, :site_entry_pages, :site_comments, :site_comment_pages
  hide_action :site_journal_entry, :instance_auto_discovery_link_tag, :param, :site_context
  helper_method :entries, :entry_pages, :groups, :group_pages, :journals, :journal_pages
  helper_method :users, :user_pages, :comments, :comment_pages
  helper_method :format_time, :users_today, :photos, :fully_qualified_domain_name
  helper_method :instance_page_title, :site_statistics, :feed_settings, :setting
  helper_method :user_is_current_user?, :current_user_is_admin?
  helper_method :site_journal, :site_entries, :site_entry_pages, :site_comments, :site_comment_pages
  helper_method :page_sort_order, :compute_setting
  helper_method :site_journal_entry, :instance_auto_discovery_link_tag, :param, :site_context
  
  def feed_settings()
    @feed_settings ||= {:encoding=> 'rss', :version=> 1.0, :images_p=> true, :full_text_p=> true,
                        :page_size=> Settings.rss_per_page}
  end
    
  def site_statistics()
    if ( nil == $SITE_STATISTICS ||
       ((Time.now - $SITE_STATISTICS[:time]) > $SITE_STATISTICS_INTERVAL))
      $SITE_STATISTICS = {:users=> User.count, :journals=> Journal.count, :groups=> Group.count,
                          :entries=> Entry.count, :words=>Entry.word_count,
                          :time=> Time.now}
     end
     $SITE_STATISTICS
  end
  
  def include_photos?()
    true
  end
  
  def include_full_text?()
    false
  end
  
  def instance_auto_discovery_link_tag(view)
    ""
  end
  
  def instance_page_title()
    Settings.page_title
  end
  
  def users_today()
    ( @user ? @user.today : Date.today )
  end
  
  def fully_qualified_domain_name()
    (Settings.wcj_host_label.blank? ? "" : (Settings.wcj_host_label + '.')) + Settings.wcj_http_domain
  end
  
  # generate a breadcrumb for the current resource
  # the base is the site root, and the next level is the controller name.
  # successive levels depend on the controller and the requested resource.
  # a single instance 
  def breadcrumb_trail()
    trail = []
    trail << ['Home', home_url]
    trail
  end
  
  def user_is_current_user?(user = @user)
    user == current_user && !(user.blank? || current_user.blank?)
  end

  def current_user_is_admin?
    (current_user && current_user.is_admin?())
  end
  
  # accepts a time instance and hash arguments comprising
  #   :format, the format argument to strftime,
  #   :time_zone, a 'local' TzinfoTimezone instance,
  #   :user, a user instance for the time zone
  def format_time(time, args={})
    def time_zone_argument_error()
      fail(ArgumentError, "time_zone must be a valid time zone designator: #{time_zone}.")
    end
    
    args.assert_valid_keys(:format, :time_zone, :user)
    format = (args[:format] || Settings.format_time_format || "%Y-%m-%dT%H:%M:%S")
    time_zone = ((user = args[:user]) ? user.timezone : ( args[:time_zone] || TzinfoTimezone[0]))
    case time_zone
    when TzinfoTimezone
    when String
      unless ( tmp = TzinfoTimezone(time_zone) )
        time_zone_argument_error()
      end
      time_zone = tmp
    else
      time_zone_argument_error()
    end
    
    # puts("args: #{args.inspect}")
    # puts("user: #{user}, time_zone: #{time_zone}")
    # puts("user.time_zone: #{user ? user.time_zone : '-'}, ")
    unless (time.utc_offset == time_zone.utc_offset)
      time = time_zone.utc_to_local(time)
    end
    time.strftime(format)
  end
  
  def comments(args = params)
    unless ( @comments && @comment_pages && (@comments_params == args) )
      @comments_params = args
      compute_comment_pages(args)
    end
    logger.debug("comments: = [#{@comments.map{|i| i.id.to_s}.join(',')}]")
    @comments
  end

  def comment_pages(args = params)
    unless @comment_pages
      compute_comment_pages(args)
    end
    @comment_pages
  end

  def entries(args = params)
    unless ( @entries && @entry_pages && (@entries_params == args))
      @entries_params = args
      compute_entry_pages(args)
    end
    @entries
  end

  def entry_pages(args = params)
    unless @entry_pages
      compute_entry_pages(args)
    end
    @entry_pages
  end

  def groups(args = params)
    unless ( @groups && @group_pages && (@groups_params == args) )
      @groups_params = args
      compute_group_pages(args)
    end
    @groups
  end

  def group_pages(args = params)
    unless ( @group_pages )
      compute_group_pages(args)
    end
    @group_pages
  end
  
  def journals(args = params)
    unless ( @journals && @journal_pages && (@journal_params == args) )
      @journals_params = args
      compute_journal_pages(args)
    end
    @journals
  end

  def journal_pages(args = params)
    unless ( @journal_pages )
      compute_journal_pages(args)
    end
    @journal_pages
  end
  
  def photos(args = params)
    # puts("photos: #{@user}")
    if (@user)
      Entry.find(:all, :limit => Settings.photo_limit,
                       :include=> [:journal],
                       :conditions => (current_user_is_admin?() ?
                                       ["photo != '' AND user_id = ?", @user.id] :
                                       ["photo != '' AND journals.scope = ? AND user_id = ?",
                                        User::SCOPE_PUBLIC, @user.id ]),
                       :order => 'entries.updated_at DESC') 
    else
      Entry.find(:all, :limit => Settings.photo_limit,
                       :include=> [:journal],
                       :conditions => (current_user_is_admin?() ?
                                       ["photo != ''"] :
                                       ["photo != '' && journals.scope = ?", User::SCOPE_PUBLIC]),
                       :order => 'entries.updated_at DESC') 
    end
  end
  
  def users(args = params)
    unless ( @users &&
             @user_pages &&
             @user_pages.items_per_page == (param([:user_page_size, :page_size], Settings.user_limit, args) || User.count) )
      compute_user_pages(args)
    end
    
    @users
  end

  def user_pages(args = params)
    unless ( @user_pages )
      compute_user_pages(args)
    end
    @user_pages
  end

  def site_journal()
    @site_journal ||= Journal.find(:first, :include => [:owner],
                                           :conditions=> [ 'journals.title = ? AND users.login = ?',
                                                           Journal::SITE_JOURNAL_TITLE,
                                                           User::ADMIN_LOGIN ])
  end
  
  def page_sort_order()
    @page_sort_order || {'column'=> '', 'order'=> ''}.with_indifferent_access
  end
  
  def site_journal_entry()
    # if there is no entry for today, create one
    # nb. race condition
    if (journal = site_journal())
      today = Date.today;
      unless ( @site_journal_entry ||= journal.entries.detect{|e| e.date == today} )
         @site_journal_entry = Entry.new()
         @site_journal_entry.date = today
         @site_journal_entry.journal = journal
         if @site_journal_entry.save
           @site_journal_entry.publish!()
           @site_journal_entry.save;
           logger.info("site journal entry saved: #{@site_journal_entry.date}")
         else
           logger.info("site journal entry not saved: #{@site_journal_entry.inspect()}")
           logger.info("site journal entry not saved: #{@site_journal_entry.errors.full_messages}")
         end
      end
    end
    @site_journal_entry
  end
  
  def site_entries(args = params)
    unless ( @site_entries )
      compute_site_entry_pages(args)
    end
    @site_entries
  end
  
  def site_entry_pages(args = params)
    unless ( @site_entry_pages )
      compute_site_entry_pages(args)
    end
    @site_entry_pages
  end
  
  def site_comments(args = params)
    unless ( @site_comments )
      compute_site_comment_pages(args)
    end
    @site_comments
  end
  
  def site_comment_pages(args = params)
    unless ( @site_comment_pages )
      compute_site_comment_pages(args)
    end
    @site_comment_pages
  end
  
  
  def site_context()
    @site_context ||= Annotation::Context.find("1")
  end
  
  def intern_param_value(value, default)
   case default
    when FalseClass, TrueClass
      case value
      when String
        ( ("false".casecmp(value) == 0) || ("0".casecmp(value) == 0) ) ? false : true
      when Integer
        (0 == value ? false : true)
      else
        value
      end
    when Integer
      # fails with bogus string param values Integer(value)
      case value
      when String
        value.to_i(10)
      else
        Integer(value)
      end
    when Float
      Float(value)
    when Symbol
      case value
      when String
        (value.blank? ? nil : value.to_sym)
      else
        value
      end
    when Time
      case value
      when Time
        value
      when String
        Time.parse(value)
      else
        value
      end
    else
      value
    end
  end
  
  def session_param(name, default = nil, override = nil)
 #   param(name, nil, default_source, default) ||
 #  param(name, default, session)  # nil session binding does _not_ override source binding
#    param(name, default, session) ||  # nil session binding does _not_ override source binding
#    param(name, default, override)
#    param(name, default, (override ? [session, override] : session))
    param(name, default, (override ? [override, session] : session))
  end
  
  def page_number_param(name, default = nil, override = nil)
    ($PAGE_NUMBERS_ARE_PERSISTENT ?
      session_param(name, default, override) :
      (param(name, nil, override, default) || param(name, default, params)) )
  end
  
#  def param(name, default=nil, source=params, prototype = default)
#    if (nil == source)
#      return default
#    end
#    # puts("param: #{name} ? #{source.inspect}")
#    if (name.respond_to?(:any?))
#     value = default
#     name.any?{|n|
#       n = n.to_s  # coerce to_s to facilitate merged parameters
#       if ( source.has_key?(n) ||
#            source.has_key?(n = (n.kind_of?(String) ? n.to_sym : n.to_s)) ) 
#         value = source[n]
#         # puts("param present: #{n}=#{value}")
#         true
#       end
#     }
#    else
#     value = (source.fetch(name.to_s, nil) || source.fetch(name.to_sym, default))
#    end
#    # puts("value: #{value}")
#    intern_param_value(value, prototype)
#  end
  def param(name, default=nil, source=params, prototype = default)
    case
    when (nil == source)
      default
    when (source.kind_of?(Array))
      value = nil
      if (source.any?{|s| value = param(name, nil, s, default) } )
        intern_param_value(value, prototype)
      else
        default
      end
    when (name.kind_of?(Array))
      value = nil
      if (name.any?{|n| value = param(n, nil, source, default) } )
        intern_param_value(value, prototype)
      else
        default
      end
    else
      if ( source.has_key?(name) ||
           source.has_key?(name = (name.kind_of?(String) ? name.to_sym : name.to_s)) ) 
        intern_param_value(source[name], prototype)
      else
        default
      end
    end
  end

  # compute and cache a presentation setting given a combination of contexts and presented instance.
  # the contexts are used as .[] stores or as the contexts for associations
  # - args, call-specific settings, eg to override paging for individual presentations (as [])
  # - session, the settings specified by the user in the past distinguished by class only (as [])
  # - user, the current user (as context)
  # - owner, the creator of the subject (as context)
  # - default context, the site defaults (as context)
  # - the subject, some combination of class and instance
  # the designation is by
  # - setting name, eg, :entry_sort, which specifies the relation predicate
  # - *facets, which indicate that the setting, itself is a .[] store, which is reduced by successive facet retrievals.
  # 
  def presentation_setting(subject, setting_name, context_chain = [])
    # puts("presentation_setting #{subject}, #{setting_name}, #{context_chain}.")
    def setting_search(subject, name, chain)
      if (chain && chain.length > 0)
        context = chain.first
        # puts("setting_search: #{context}, #{subject}, #{name}, [#{chain}] ? #{context.respond_to?(:context_setting)}.")
        if (context.respond_to?(:context_setting))
          # puts("setting_search: #{context}, #{subject}, #{name}, [#{chain}].")
          if (value = context.context_setting(self, subject, name, chain[1..-1]) {|s,n,c| setting_search(s, n, c)})
            value
          end
        else
          setting_search(subject, name, chain[1..-1])
        end
      else
        nil
      end
    end
    
    subject = (case
               when subject.kind_of?(String)
                 subject
               when subject.respond_to?(:id)
                 subject
               when subject.kind_of?(Module)
                 subject.name.to_s
               when subject.kind_of?(Symbol)
                 subject.to_s
               else
                 subject.class.name.to_s
               end)
    setting_name = setting_name.to_s
    setting_search(subject, setting_name, context_chain)
  end
    
  
  protected
  
  def record_request(instance)
    if Settings.model_statistics_p
      request_uri = ModelStatistic.canonicalize_uri(request.request_uri)
      referer_uri = ModelStatistic.canonicalize_uri(request.env["HTTP_REFERER"])
      stat = ModelStatistic.create(:instance => instance,
                                    :user=> current_user,
                                    :request_uri => request_uri,
                                    :remote_addr => request.env["REMOTE_ADDR"],
                                    :referer => referer_uri,
                                    :session_id => session.session_id
                                    )
      # unless (stat.save!)
      #   logger.warn("stats save failed: #{$!}, #{stat.errors.full_messages}")
      # end
    end
  end
  
  def self.sidebar_setting(page, name, default= 'sidebar')
    if (positions = Settings.sidebars[page])
      position = positions.fetch(name, default) #(positions.has_key?(name) ? positions.fetch(name) : default)
      if position
        position = position.to_sym.to_s  # otherwise it did not match
      else
        position = nil
      end
    else
      position = default
    end
    # puts("sidebar_setting: #{name}: #{position}")
    position
  end
        
  #def default_to_guest
  #  unless logged_in?
  #    anonymous = User.new(:login => 'anonymous', :first_name => 'Anonymous', :last_name => 'Guest')
  #    anonymous.assign_role(:guest)
  #    anonymous.readonly!
  #    self.current_user = anonymous
  #  end
  #end
  
  # instance resolution
  # observes entry state, but not scope.
  # the latter is enforec by the respective controller, so that the error can differentiate non-existent, read access, write access

  # entry resolution
  # if a journal is bound, constrain by its state and select the entry by date
  # otherwise, resolve the entry by id and constrain by its journal's state
  def find_entry(args = params)
    if @journal
      (@journal.active? ?  # double-check that the journal is active
       (@date ? @journal.entries.find_by_date(@date) : ((id = params[:entry_id]) ? @journal.entries.find_by_id(id) : nil)) :
       nil)
    else
      ( ((entry_id = params[:entry_id])  && (entry = Entry.find(entry_id)) &&
         (entry.active? || current_user_is_admin?)) ?
        entry : nil )
    end
  end
  
  def find_entry!(args = params)
    if (@entry ||= find_entry(params))
      @entry
    else
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end

  def entry_specified?()
    @entry != nil
  end


  # Use the Journal instance retrieval to locate a journal given the
  # request query parameters.
  def find_journal(args = params)
    journal = Journal::find_instance(args)
    # constrain for active state
    if (journal && (journal.active? || current_user_is_admin?))
      journal
    else
      fail(Journal::NotFoundError, "Journal not active [context: id]: #{journal ? journal.id : 0}")
    end
  end
 
  # Find and return a journal as for find_journal.
  # In addition set @journal to the result
  def find_journal!(args = params)
    begin
      @journal = find_journal(args)
    rescue ArgumentError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    rescue Journal::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end

  def find_journal_if_specified!(args = params)
    begin
      @journal = find_journal(args)
    rescue ArgumentError
      @journal = nil
    rescue Journal::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end

  def journal_specified?()
    @journal != nil
  end


  # Use the Group instance retrieval to locate a group given the
  # request query parameters.
  def find_group(args = params)
    group = Group::find_instance(args)
    # constrain for active state
    if (group && (group.active? || current_user_is_admin?))
      group
    else
      fail(Group::NotFoundError, "Group not active [context: id]: #{group ? group.id : 0}")
    end
  end
 
  # Find and return a journal as for find_journal.
  # In addition set @journal to the result
  def find_group!(args = params)
    begin
      @group = find_group(args)
    rescue ArgumentError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    rescue Group::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end
  
  def find_group_if_specified!(args = params)
    begin
      @group = find_group(args)
    rescue ArgumentError
      @group = nil
    rescue Group::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end
  
  def group_specified?()
    @group != nil
  end


  # Use the User instance retrieval to locate a user given the
  # request query parameters.
  def find_user(args = params)
    user = User::find_instance(args)
    # constrain for active state
    if (user && (user.active? || current_user_is_admin?))
      user
    else
      fail(User::NotFoundError, "user not active [context: id]: #{user ? user.id : 0}")
    end
  end
 
  # Find and return a journal as for find_journal.
  # In addition set @journal to the result
  # if no user was designated, default to the logged-in user
  def find_user!(args = params)
    begin
      @user = find_user(args)
    rescue ArgumentError
      if (CURRENT_USER_IS_DEFAULT_USER && logged_in?)
        return (@user = current_user())
      else
        flash[:notice] = $!.message()
        render(:action=>:not_found, :status=>"404 Not Found")
        return(false)
      end
    rescue User::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end

  def find_user_if_specified!(args = params)
    begin
      @user = find_user(args)
    rescue ArgumentError
      if (CURRENT_USER_IS_DEFAULT_USER && logged_in?)
        return (@user = current_user())
      else
        @user = nil
      end
    rescue User::NotFoundError
      flash[:notice] = $!.message()
      render(:action=>:not_found, :status=>"404 Not Found")
      return(false)
    end
  end
  
  def user_specified?()
    @user != nil
  end


  # pagination, in general, suggests to follow this example:
  # 
  #     @person_pages = Paginator.new self, Person.count, 10, params[:page]
  #     @people = Person.find :all, :order => 'last_name, first_name',
  #                           :limit  =>  @person_pages.items_per_page,
  #                           :offset =>  @person_pages.current.offset
  #                           
  # this standard example must be modified, since the effective extent is not given by <Class>.count,
  # but is reduced by the scope and status constraints. therefore the first step is to
  # collect the page-set given the constraints and, if the set is as large as the limit, use the
  # class count, otherwise combine the page number and set length to compute the actual count.

  # removed, since the more accurate extent count doesn't sue the class extent
  # def make_paginator(context, collection_class, collection, page_size, page_number, extent_count = collection_class.count)
  #   Paginator.new(context, extent_count, [page_size, collection.length].max, page_number)
  # end

  # compute comment pages w/ optional @user or @journal context, eg, for the site index page
  # restrict comments to those in active journals, again which are either public or (unless admin) owned
  # by the current user. group transitivity is not observed.
  # take the sort specifications from the session, the request user or journal, or the site defaults
  def compute_comment_pages(args = {})
    page_size = session_param([:comment_page_size, :comment_size], Settings.comment_limit, args) || Comment.count
    page_number = page_number_param([:comment_page, :page], 1, args)
    conditions = []
    comment_sort = (presentation_setting(Comment, :comment_sort, [args, session, current_user, @journal, site_context()]) || {})
    sort_column = comment_sort['column'] || 'created_at'
    sort_order = comment_sort['order'] || Settings.comment_sort_oder
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
    offset = (page_number - 1) * page_size # used in some of the sql queries
    case
    when @entry
      logger.debug("AC#c_c_p: entry case")
      # limit the comments to those in the specific entry, constrained to be from active users
      # uses modified equivalent to Commentable#comments_ordered_by_submitted
      @comments = (case
                   when current_user_is_admin?()
                     Comment.find(:all, :limit => page_size,
                                        :offset => (page_number - 1) * page_size,
                                        :conditions => (conditions = ["commentable_id = ? AND commentable_type = 'Entry'", @entry.id]),
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => "comments." + order_option )
                   else
                     Comment.find(:all, :limit => page_size,
                                        :include => [:user],
                                        :offset => (page_number - 1) * page_size,
                                        :conditions => (conditions = ["commentable_id = ? AND commentable_type = 'Entry' AND users.state = ?",
                                                                      @entry.id, User::STATE_ACTIVE ]),
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => "comments." + order_option )
                   end)
    when @journal
      logger.debug("AC#c_c_p: journal case")
      @comments = (case
                   when (current_user_is_admin?())
                    Comment.find_by_sql(conditions = [ "SELECT SQL_CALC_FOUND_ROWS c.* FROM comments AS c
                                                      LEFT JOIN entries AS e ON c.commentable_id = e.id AND c.commentable_type = 'Entry'
                                                         WHERE (entries.journal_id = ?)
                                                      ORDER BY c.#{order_option} LIMIT #{offset}, #{page_size}",
                                                               @journal.id ])
                  when (@journal.is_public?() ||
                        (logged_in && Comment.count_by_sql( "SELECT count(*) where groups_users.user_id = ? AND groups_users.group_id = groups_journals.journal_id && groups_journals.journal_id = ?") > 0))
                     Comment.find_by_sql(conditions = [ "SELECT SQL_CALC_FOUND_ROWS c.* FROM comments AS c
                                                      LEFT JOIN entries AS e ON c.commentable_id = e.id AND c.commentable_type = 'Entry'
                                                      LEFT JOIN users AS c_u ON c.user_id = c_u.id
                                                          WHERE ( e.journal_id = ? AND c_u.scope = ? AND c_u.state = ? )
                                                       ORDER BY c.#{order_option} LIMIT #{offset}, #{page_size}",
                                                       @journal.id, User::SCOPE_PUBLIC, User::STATE_ACTIVE ])
                   else
                    []
                   end )
    when @user
      logger.debug("AC#c_c_p: user case")
      # limit the comments to those by a specific author. if the current user is also the author, include all
      # about active journals, otherwise require also that the journal be public
      @comments = (case
                   when (current_user_is_admin?())
                     Comment.find(:all, :limit => page_size,
                                        :offset=> (page_number - 1) * page_size,
                                        :conditions=> (conditions = [ "comments.user_id = ?", @user.id() ]),
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => "comments." + order_option)
                   when (user_is_current_user?() || (@user.is_public? && @user.active?))
                     # commment may have been for a journal which is now private or deactivated
                     # cannot rely on simple find with :include=> [:commentable, :journals] for journal, since that yields a ActiveRecord::EagerLoadPolymorphicError
                     Comment.find_by_sql(conditions = [ "SELECT SQL_CALC_FOUND_ROWS c* FROM comments AS c
                                                      LEFT JOIN entries AS e ON c.commentable_id = e.id AND c.commentable_type = 'Entry'
                                                      LEFT JOIN journals AS j ON e.journal_id = j.id
                                                      LEFT JOIN users AS j_u ON j.user_id = j_u.id
                                                          WHERE c.user_id = ? AND j.scope = ? AND j.state = ? AND j_u.scope = ? AND j_u.state = ? 
                                                       ORDER BY c.#{order_option} LIMIT #{offset}, #{page_size}",
                                                                @user.id(), Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE,
                                                                User::SCOPE_PUBLIC, User::STATE_ACTIVE ])
                   else
                    []
                   end )
    else
      logger.debug("AC#c_c_p: general case")
      @comments = (case
                   when current_user_is_admin?()
                    Comment.find(:all, :limit => page_size,
                                        :offset=> (page_number - 1) * page_size,
                                        :select=> 'SQL_CALC_FOUND_ROWS *',
                                        :order => "comments." + order_option)
                   else
                     Comment.find_by_sql(conditions = [ "SELECT SQL_CALC_FOUND_ROWS c.* FROM comments c
                                                      LEFT JOIN entries AS e ON c.commentable_id = e.id AND c.commentable_type = 'Entry'
                                                      LEFT JOIN users AS c_u ON c.user_id = c_u.id
                                                      LEFT JOIN journals AS j ON e.journal_id = j.id
                                                      LEFT JOIN users AS j_u ON j.user_id = j_u.id
                                                          WHERE ( j.scope = ? AND j.state = ? AND j_u.scope = ? AND j_u.state = ? AND c_u.scope = ? AND c_u.state = ? )
                                                       ORDER BY c.#{order_option} LIMIT #{offset}, #{page_size}",
                                                                Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE,
                                                                User::SCOPE_PUBLIC, User::STATE_ACTIVE,
                                                                User::SCOPE_PUBLIC, User::STATE_ACTIVE ])
                   end )
    end
    extent_count = User.count_by_sql('SELECT FOUND_ROWS()')
    @comment_pages =
      Paginator.new(self, extent_count, [page_size, @comments.length].max, page_number)
    logger.debug("AC#c_c_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} user: #{@user ? @user.id : '-'} journal: #{@journal ? @journal.id : '-'}")
    logger.debug("AC#c_c_p: ? [#{conditions.join(' ')}] x #{order_option}")
    logger.debug("AC#c_c_p: = [#{@comments.map{|i| i.id.to_s}.join(',')}]/#{@comment_pages.page_count}/#{@comment_pages.item_count}")
  end
  
  # compute entry pages w/ optional user context, eg, for the site index page
  # where the user is specified, select entries from journals which the user authors
  # optionally constrain to be entries with photos
  def compute_entry_pages(args = {})
    page_size = session_param([:entry_page_size, :page_size], Settings.entry_limit, args) || Entry.count
    page_number = page_number_param([:entry_page, :page], 1, args)
    require_photo = session_param(:require_photo, @require_photo, args)
    conditions = []
    # puts("a_c#c_e_p: args: #{args.inspect}")
    # puts("a_c#c_e_p: params: #{params.inspect}")
    # puts("a_c#c_e_p: session pre: #{session.inspect}")
    entry_sort = (presentation_setting((@journal || Entry), :entry_sort, [args, session, current_user, @journal, @user, site_context()]) || {})
    sort_column = entry_sort['column'] || 'date'
    sort_order = entry_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "entries.#{@page_sort_order['column']} #{@page_sort_order['order']}"
    # puts("a_c#c_e_p: session post: #{session.inspect}")
    # puts("a_c#c_e_p: entry_sort: #{entry_sort.inspect}")
    # puts("a_c#c_e_p: @page_sort_order: #{@page_sort_order.inspect}")
 
    if ( @user )
      # include requires an explicit count, as the generated sql does not include the hint
      @entries = ( current_user_is_admin? ?
                   Entry.find(:all, :include => [:journal],
                                    :limit => page_size,
                                    :offset=> (page_number - 1) * page_size,
                                    :conditions=> (conditions = ['journals.user_id = ?', @user.id()]),
                                    :order => order_option) :
                   Entry.find(:all, :include => [:journal],
                                    :limit => page_size,
                                    :offset=> (page_number - 1) * page_size, 
                                    :conditions => (conditions = [ ("journals.user_id = ? && journals.scope=? && journals.state = ? && entries.state = ?" +
                                                                    (require_photo ? " AND photo != ''" : "")),
                                                                   @user.id(), User::SCOPE_PUBLIC, Journal::STATE_ACTIVE, 'published' ]),
                                    :order => order_option) )
      extent_count = Entry.count(:conditions => conditions, :include => [:journal])
    else
      @entries = ( current_user_is_admin? ?
                 Entry.find(:all, :limit => page_size,
                                  :offset=> (page_number - 1) * page_size,
                                  :select=> 'SQL_CALC_FOUND_ROWS *', 
                                  :order => order_option) :
                 Entry.find(:all, :include=> [:journal],
                                  :limit => page_size,
                                  :offset=> (page_number - 1) * page_size, 
                                  :conditions => (conditions = [ ("journals.scope=? && journals.state = ? && entries.state = ?" +
                                                                  (require_photo ? " AND photo != ''" : "")),
                                                                 User::SCOPE_PUBLIC, Journal::STATE_ACTIVE, 'published' ]),
                                  :select=> 'SQL_CALC_FOUND_ROWS *', 
                                  :order => order_option) )
      extent_count = Entry.count_by_sql('SELECT FOUND_ROWS()')
    end
    @entry_pages =
      Paginator.new(self, extent_count, [page_size, @entries.length].max, page_number)
    logger.debug("AC#c_e_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} user: #{@user ? @user.id : '-'}")
    logger.debug("AC#c_e_p: ? [#{conditions.join(' ')}] x #{order_option}")
    logger.debug("AC#c_e_p: = [#{@entries.map{|i| i.id.to_s}.join(',')}]/#{@entry_pages.page_count}/#{@entry_pages.item_count}")
  end

  # compute group pages w/ optional @user context, eg, for the site index page
  def compute_group_pages(args = {})
    page_size = session_param([:group_page_size, :page_size], Settings.group_limit, args) || Group.count
    page_number = page_number_param([:group_page, :page], 1, args)
    conditions = []
    group_sort = (presentation_setting(Group, :group_sort, [args, session, current_user, @user, site_context()]) || {})
    sort_column = group_sort['column'] || 'created_at'
    sort_order = group_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
    
    if ( @user )
      @groups = ( (current_user_is_admin?() || user_is_current_user?()) ?
                 Group.find(:all, :limit => page_size,
                                  :offset=> (page_number - 1) * page_size,
                                  :conditions=> (conditions = [ "user_id = ?", @user.id() ]),
                                  :order => order_option) :
                 Group.find(:all, :limit => page_size,
                                  :offset=> (page_number - 1) * page_size,
                                  :conditions=> (conditions = [ "user_id = ? && scope =? && state = ?", @user.id(), Group::SCOPE_PUBLIC, Group::STATE_ACTIVE ]),
                                  :select=> 'SQL_CALC_FOUND_ROWS *',
                                  :order => order_option))
    else
      @groups = (current_user_is_admin?() ?
                 Group.find(:all, :limit => page_size,
                                  :offset=> (page_number - 1) * page_size,
                                  :select=> 'SQL_CALC_FOUND_ROWS *',
                                  :order => order_option) :
                 Group.find(:all, :limit => page_size,
                                  :offset=> (page_number - 1) * page_size,
                                  :conditions=> (conditions = [ "scope=? && state = ?", Group::SCOPE_PUBLIC, Group::STATE_ACTIVE ]),
                                  :select=> 'SQL_CALC_FOUND_ROWS *',
                                  :order => order_option))
    end
    extent_count = User.count_by_sql('SELECT FOUND_ROWS()')
    @group_pages =
      Paginator.new(self, extent_count, [page_size, @groups.length].max, page_number)
    logger.debug("AC#c_g_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} user: #{@user ? @user.id : '-'}")
    logger.debug("AC#c_g_p: ? [#{conditions.join(' ')}] x #{order_option}")
    logger.debug("AC#c_g_p: = [#{@groups.map{|i| i.id.to_s}.join(',')}]/#{@group_pages.page_count}/#{@group_pages.item_count}")
  end
                                        
  # compute journal pages w/ optional @user context, eg, for the site index page
  def compute_journal_pages(args = {})
    page_size = session_param([:journal_page_size, :page_size], Settings.journal_limit, args) || Journal.count
    page_number = page_number_param([:journal_page, :page], 1, args)
    conditions = []
    journal_sort = (presentation_setting(Journal, :journal_sort, [args, session, current_user, @user, site_context()]) || {})
    sort_column = journal_sort['column'] || 'updated_at'
    sort_order = journal_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
    
    if ((args == nil || args == params) &&
        (search_option = params[:search]).kind_of?(Hash) &&
        (search_value = search_option['value']).kind_of?(String))
      search_by = search_option['by']
      search_relation = search_option['relation']
      search_value = '%' + search_value + '%'
      # puts("compute_journal_pages: callers: #{caller()[0..15].join(' ')}")
      # puts("compute_journal_pages: args: #{args.inspect}: #{search_option.inspect}  #{page_number},#{page_size}")
      # require an explicit page in the call/request otherwise use page 1
      # don't use session-cached value
      unless (params[:journal_page] || params[:page])
        page_number = 1;
      end
      
      case search_by
      when 'user', 'users'
        case search_relation
        when 'name'
          if (current_user_is_admin?())
            @journals = Journal.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS j.* FROM users u, journals j
                                                            WHERE j.user_id = u.id AND (first_name LIKE ? OR last_name LIKE ?)
                                                            ORDER BY j.#{order_option}",
                                                            search_value, search_value]))
          else
            @journals = Journal.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS j.* FROM users u, journals j
                                                            WHERE j.user_id = u.id AND (first_name LIKE ? OR last_name LIKE ?) AND u.state = ? AND u.scope = ? AND j.state = ? AND j.scope = ?
                                                            ORDER BY j.#{order_option}",
                                                            search_value, search_value, User::STATE_ACTIVE, User::SCOPE_PUBLIC, Journal::STATE_ACTIVE, Journal::SCOPE_PUBLIC]))
          end
        else
          if (current_user_is_admin?())
            @journals = Journal.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS j.* FROM users u, journals j
                                                            WHERE j.user_id = u.id AND u.login LIKE ?
                                                            ORDER BY j.#{order_option}",
                                                            search_value]))
          else
            @journals = Journal.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS j.* FROM users u, journals j
                                                            WHERE j.user_id = u.id AND u.login LIKE ? AND u.state = ? AND u.scope = ? AND j.state = ? AND j.scope = ?
                                                            ORDER BY j.#{order_option}",
                                                            search_value, User::STATE_ACTIVE, User::SCOPE_PUBLIC, Journal::STATE_ACTIVE, Journal::SCOPE_PUBLIC]))
          end
        end
      else
        if current_user_is_admin?()
         @journals = Journal.find(:all, :limit => page_size,
                            :offset=> (page_number - 1) * page_size,
                            :conditions=> (conditions = [ "title LIKE ?", search_value ]),
                            :select=> 'SQL_CALC_FOUND_ROWS *',
                            :order => order_option)
        else
         @journals = Journal.find(:all, :limit => page_size,
                            :offset=> (page_number - 1) * page_size,
                            :conditions=> (conditions = [ "title LIKE ? AND scope=? AND state=?", search_value, Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE ]),
                            :select=> 'SQL_CALC_FOUND_ROWS *',
                            :order => order_option)
        end
      end
    elsif (@user)
      # constrain the constituents by current user's privileges
      @journals = ( (current_user_is_admin?() || user_is_current_user?()) ?
         Journal.find(:all, :limit => page_size,
                            :offset=> (page_number - 1) * page_size,
                            :conditions=> (conditions = [ "user_id = ?", @user.id() ]),
                            :select=> 'SQL_CALC_FOUND_ROWS *',
                            :order => order_option) :
         Journal.find(:all, :limit => page_size,
                            :offset=> (page_number - 1) * page_size,
                            :conditions=> (conditions = [ "user_id = ? AND scope=? AND state=?", @user.id(), Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE ]),
                            :select=> 'SQL_CALC_FOUND_ROWS *',
                            :order => order_option) )
    else
      # list without content qualification
      # nb. can't order on entries as that fails for journals with no entries.
      @journals = (current_user_is_admin?() ?
                  Journal.find(:all, :limit => page_size,
                                     :offset=> (page_number - 1) * page_size,
                                     :select=> 'SQL_CALC_FOUND_ROWS *',
                                     :order => order_option) :
                  Journal.find(:all, :limit => page_size,
                                     :offset=> (page_number - 1) * page_size,
                                     :conditions => (conditions = [ "scope=? AND state=?", Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE ]),
                                     :select=> 'SQL_CALC_FOUND_ROWS *',
                                     :order => order_option) )
    end
    extent_count = Journal.count_by_sql('SELECT FOUND_ROWS()')
    @journal_pages =
      Paginator.new(self, extent_count, [page_size, @journals.length].max, page_number)
    logger.debug("AC#c_j_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} user: #{@user ? @user.id : '-'}")
    logger.debug("AC#c_j_p: ? [#{conditions.join(' ')}] x #{order_option}")
    logger.debug("AC#c_j_p: = [#{@journals.map{|i| i.id.to_s}.join(',')}]/#{@journal_pages.page_count}/#{@journal_pages.item_count}")
  end
  
  
  # compute user pages w/o context, eg, for the site index page
  def compute_user_pages(args = {})
    page_size = session_param([:user_page_size, :page_size], Settings.list_users_count, args) || User.count
    page_number = page_number_param([:user_page, :page], 1, args)
    require_avatar = session_param(:require_avatar, @require_avatar, args)
    require_description = session_param(:require_description, @require_description, args)
    conditions = []
    user_sort = (presentation_setting(User, :user_sort, [args, session, current_user, site_context()]) || {})
    sort_column = user_sort['column'] || 'created_at'
    sort_order = user_sort['order'] || 'DESC'
    @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
    order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
    # puts("compute_user_pages: callers: #{caller()[0..15].join(' ')}")
    # puts("compute_user_pages: args: #{args.inspect}: #{search_option.inspect}  #{page_number},#{page_size}")
    if ((search_option = ((args && args != params) ? nil : params[:search])).kind_of?(Hash) &&
        (search_value = search_option['value']).kind_of?(String))
      search_by = search_option['by']
      search_relation = search_option['relation']
      search_value = '%' + search_value + '%'
      # require an explicit page in the call/request otherwise use page 1
      # don't use session-cached value
      unless (params[:user_page] || params[:page])
        page_number = 1;
      end
      
      case search_by
      when 'journal', 'journals'
        if current_user_is_admin?()
          @users = User.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS u.* FROM users u, journals j
                                                   WHERE j.user_id = u.id AND j.title LIKE ?
                                                   ORDER BY #{order_option}",
                                                   search_value]))
        else
          @users = User.find_by_sql((conditions = ["SELECT SQL_CALC_FOUND_ROWS u.* FROM users u, journals j
                                                    WHERE j.user_id = u.id AND j.title LIKE ? AND u.state = ? AND u.scope = ? AND j.state = ? AND j.scope = ?
                                                    ORDER BY #{order_option}",
                                                    search_value, User::STATE_ACTIVE, User::SCOPE_PUBLIC, Journal::STATE_ACTIVE, Journal::SCOPE_PUBLIC]))
        end
      else
        case search_relation
        when 'name'
          if (current_user_is_admin?())
            @users = User.find(:all, :limit => page_size,
                               :offset=> (page_number - 1) * page_size,
                               :conditions => (conditions = ["first_name LIKE ? OR last_name LIKE ?",
                                                             search_value, search_value]),
                               :select=> 'SQL_CALC_FOUND_ROWS *',
                               :order => order_option)
          else
             @users = User.find(:all, :limit => page_size,
                                :offset=> (page_number - 1) * page_size,
                                :conditions => (conditions = ["state = ? AND scope = ? AND (first_name LIKE ? OR last_name LIKE ?)",
                                                              User::STATE_ACTIVE, User::SCOPE_PUBLIC,
                                                              search_value, search_value]),
                                :select=> 'SQL_CALC_FOUND_ROWS *',
                                :order => order_option)
          end
        when 'email'
          if (current_user_is_admin?())
            @users = User.find(:all, :limit => page_size,
                               :offset=> (page_number - 1) * page_size,
                               :conditions => (conditions = ["email LIKE ?",
                                                             search_value]),
                               :select=> 'SQL_CALC_FOUND_ROWS *',
                               :order => order_option)
          else
            @users = User.find(:all, :limit => page_size,
                               :offset=> (page_number - 1) * page_size,
                               :conditions => (conditions = ["email LIKE ? AND state = ? AND scope = ?",
                                                             search_value,
                                                             User::STATE_ACTIVE, User::SCOPE_PUBLIC]),
                               :select=> 'SQL_CALC_FOUND_ROWS *',
                               :order => order_option)
          end
        else
          if (current_user_is_admin?())
            @users = User.find(:all, :limit => page_size,
                               :offset=> (page_number - 1) * page_size,
                               :conditions => (conditions = ["login LIKE ?",
                                                             search_value]),
                               :select=> 'SQL_CALC_FOUND_ROWS *',
                               :order => order_option)
          else
            @users = User.find(:all, :limit => page_size,
                               :offset=> (page_number - 1) * page_size,
                               :conditions => (conditions = ["login LIKE ? AND state = ? AND scope = ?",
                                                             search_value,
                                                             User::STATE_ACTIVE, User::SCOPE_PUBLIC]),
                               :select=> 'SQL_CALC_FOUND_ROWS *',
                               :order => order_option)
          end
        end
      end
    else # list without content qualification
      conditions = (current_user_is_admin?() ?
                    nil :
                    [("state = ? AND scope = ?" +
                      (require_avatar ? " AND avatar != ''" : "") +
                      (require_description ? " AND description != ''" : "")),
                     User::STATE_ACTIVE, User::SCOPE_PUBLIC] )
      @users = User.find(:all, :limit => page_size,
                         :offset=> (page_number - 1) * page_size,
                         :conditions => conditions,
                         :select=> 'SQL_CALC_FOUND_ROWS *',
                         :order => order_option)
    end
    extent_count = User.count_by_sql('SELECT FOUND_ROWS()')
    @user_pages =
      Paginator.new(self, extent_count, [page_size, @users.length].max, page_number)
    logger.debug("AC#c_u_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} avatar/description: #{require_avatar}/#{require_description}")
    logger.debug("AC#c_u_p: ? [#{conditions ? conditions.join(' ') : '-'}] x #{order_option}")
    logger.debug("AC#c_u_p: = [#{@users.map{|i| i.id.to_s}.join(',')}]/#{@user_pages.page_count}/#{@user_pages.item_count}")
  end
   
  def compute_site_entry_pages(args = {})
    page_size = session_param([:entry_page_size, :page_size], Settings.entry_limit, args) || User.count
    page_number = page_number_param([:site_journal_page, :page], 1, args)
    journal = site_journal()
    entry_order = 'updated_at DESC'
    conditions = []
    @site_entries = (current_user_is_admin?() ?
                     Entry.find(:all, :limit => page_size,
                                      :offset=> (page_number - 1) * page_size,
                                      :conditions=> (conditions = ['journal_id = ?', journal.id()]),
                                      :select=> 'SQL_CALC_FOUND_ROWS *',
                                      :order => entry_order) :
                     Entry.find(:all, :limit => page_size,
                                      :offset=> (page_number - 1) * page_size, 
                                      :conditions => (conditions = [ "journal_id = ? && state = ?", journal.id(), 'published' ]), 
                                      :select=> 'SQL_CALC_FOUND_ROWS *',
                                      :order => entry_order) )
    extent_count = Entry.count_by_sql('SELECT FOUND_ROWS()')
    @site_entry_pages =
      Paginator.new(self, extent_count, [page_size, @site_entries.length].max, page_number)
    logger.debug("AC#c_s_e_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size}")
    logger.debug("AC#c_s_e_p: ? [#{conditions.join(' ')}]")
    logger.debug("AC#c_s_e_p: = [#{@site_entries.map{|i| i.id.to_s}.join(',')}]/#{@site_entry_pages.page_count}/#{@site_entry_pages.item_count}")
  end
  
  def compute_site_comment_pages(args = {})
    page_size = session_param([:comment_page_size, :page_size], Settings.comment_limit, args) || User.count
    page_number = page_number_param([:site_comment_page, :page], 1, args)
    journal = site_journal()
    offset = (page_number - 1) * page_size
    # nb. this does not work:
    # ==> Can not eagerly load the polymorphic association :commentable
#    Comment.with_scope(:find=> {:conditions=> ['entries.journal_id = ?', journal.id()],
#                                :include=> [:commentable]}) {
#      @site_comments = Comment.find(:all, :limit => page_size,
#                                          :offset=> (page_number - 1) * page_size,
#                                          :order=> 'updated_at DESC',
#                                          :conditions => [ "comments.state = ?",
#                                                           'published'])
#    }
    @site_comments = Comment.find_by_sql(["SELECT SQL_CALC_FOUND_ROWS c.*, e.state, e.journal_id FROM comments c, entries e WHERE c.commentable_type = 'Entry' AND c.commentable_id = e.id AND e.journal_id = ? AND e.state = ? AND c.state = ? LIMIT #{offset}, #{page_size}",
                                          journal.id, 'published', 'published'])
    extent_count = Entry.count_by_sql('SELECT FOUND_ROWS()')
    @site_comment_pages =
      Paginator.new(self, extent_count, [page_size, @site_comments.length].max, page_number)
    logger.debug("AC#c_s_c_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size}")
    logger.debug("AC#c_s_c_p: = [#{@site_comments.map{|i| i.id.to_s}.join(',')}]/#{@site_comment_pages.page_count}/#{@site_comment_pages.item_count}")
  end
  
  # interleave new entries into a sequence for those dates when no entry is present
  def fill_entries(entries, journal, bounds={})
    # puts("fill_entries:\nbefore: #{entries.map{|e| e.date.to_s}.inspect}")
    filled_entries = []
    start_date = bounds[:start] || journal.start_date()
    end_date = bounds[:end] || [journal.end_date(), journal.today()].min
    # puts("fill_entries: start: #{start_date}, end: #{end_date}")
    expected_date = end_date
    # puts(entries.map{|e| e.date.to_s}.inspect)
    if (entries.length() > 0)
      # puts("initial date: #{expected_date}")
      entries.map{|e|
        delta = expected_date - e.date
        if ( delta > 0)
          # puts("filling #{delta} days")
          0.upto(delta-1){ |i|
            missing_date = expected_date - i
            # puts("filling date: #{missing_date}")
            filled_entries << Entry.new( :date=> missing_date, :journal=> journal)
          }
        end
        filled_entries << e
        # puts("using entry date: #{e.date}")
        expected_date = e.date - 1
        # puts("next date: #{expected_date}")
      }
    end

    # extend between earliest and start date
    delta = expected_date - start_date
    if (delta >= 0)
      # puts("extending #{delta = 1} days")
      0.upto(delta){ |i|
        missing_date = expected_date - i
        # puts("extending with date: #{missing_date}")
        filled_entries << Entry.new( :date=> missing_date, :journal=> journal)
      }
    end
    # puts("after: #{filled_entries.map{|e| e.date.to_s}.inspect}")
    filled_entries
  end
  
  def canonical_sort_column(column)
    value=
    case column
    when String, Symbol
      $SORT_COLUMN_MAP[column.to_s.downcase]
    else
      $SORT_COLUMN_MAP.default
    end
  end
  
  def canonical_sort_order(order)
    value = 
    case order
    when String, Symbol
      $SORT_ORDER_MAP[order.to_s.downcase]
    else
      $SORT_ORDER_MAP.default
    end
  end
  
  def intern_query_parameter(args)
    case
    when !((type = param('type', nil, args)).blank?)
      if (klass = ASSERTION_CLASS_MAP[type])
        id = param('id', nil, args)
        begin
          ((id.blank?() || '0' == id) ? klass : klass.find(id))
        rescue Exception
          logger.warn("intern_query_parameter: '#{klass}.#{text}: #{$!}")
          nil
        end
      end
    when !((text = param('text', nil, args)).blank?)
      begin
        value = YAML::load(text)
      rescue Exception
        logger.warn("intern_query_parameter: '#{text}: #{$!}")
        nil
      end
    else
      nil
    end
  end
  
  def render_assertion_response(assertions)
    respond_to do |wants|
      wants.html {
        render('partials/_assertion_description')
      }
      wants.js { @assertion_message = '' 
        render(:partial=> 'assertion_data')
      }
    end
  end
  
  def cook_query_parameter(name)
    cache_op = nil
    case name
    when Array
      as = name[1]
      cache_op = name[2]
      name = name[0]
    else
      as = name
    end
    
    if (value = params[name])
      if (cache_op)
        cache_op.call(session, name, as.to_s, value)
      else
        session[as.to_s] = value
      end
    end
  end
  
  # run as a before filter to collect specified query parameters into the
  # session. iterates over the controller class precedence list up to and
  # including ApplicationController to extract and apply the spec
  def cook_params(context = self.class)
    if (context.const_defined?(:SESSION_PARAMS))
      context.const_get(:SESSION_PARAMS).each{|p| cook_query_parameter(p)}
      unless ApplicationController == context
        cook_params(context.superclass)
      end
    end
  end
  
end
