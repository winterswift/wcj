#!ruby
#
# Word Count Journal controller for groups
# (c) 2006 makalumedia
# 
# 2006-11-18  james.anderson  find!
# 2006-11-19  james.anderson  logging
# 2006-11-20  james.anderson  (WCJ-ASC-F01 WCJ-ASC-F02) added is_admin? to restrict_access
# 2006-11-26  james.anderson  added entry_class (adresses #15)
# 2006-11-29  james.anderson  new, create for comments (adresses #68)
# 2006-11-10  james.anderson  added fill option for missing entries.
# 2006-12-06  james.anderson  added read access restrictions
# 2006-12-24  james.anderson  use User#today for date if the @user is present.

VERSIONS[__FILE__] = "$Id: entries_controller.rb 876 2007-05-14 09:19:56Z alex $"

require "entry_calendar_controller"
require "annotation"

class EntriesController < ApplicationController
  include ActionView::Helpers::TextHelper
  include EntryCalendarController
  
  FILL_JOURNAL_ENTRIES = true;
  FILL_USER_ENTRIES = true;
  SESSION_PARAMS = [['page', 'entry_page'], ['page_size', 'entry_page_size'],
                    'entry_page', 'entry_page_size']

  @@rss_per_page = Settings.rss_per_page || 20;
  # @@html_per_page = Settings.html_per_page || 7;

  access_rule 'user || admin', :only => [:assert, :deny, :create, :edit, :update, :new,
                                         :new_comment, :create_comment,
                                         :subscribe_user, :unsubscribe_user]
  access_rule 'admin', :only => [:destroy, :list]
  
  # always at least try to find the user and journal
  before_filter :find_user_if_specified!, :only => [:index, :list]
  before_filter :find_user!, :except => [:index, :list]
  # intern the date after the user in order to use their today as the default
  before_filter :get_date, :except => [:index, :list]
  before_filter :find_journal_if_specified!, :only => [:index, :list]
  before_filter :find_journal!, :except => [:index, :list]
  before_filter :find_entry!, :except => [:new, :create, :index, :list]
  # other logged-in users can comment on an entry or subscribe to it, but they need not
  # own it
  before_filter :restrict_write, :only => [:assert, :deny, :new, :create, :edit, :update, :destroy]
  # enforce scope
  before_filter :restrict_read, :only=> [:rss, :show]

  sidebar :entry_photo, :only => :show, :position => 'sidebar'
  #sidebar :journal_about, :if => :journal_specified?, :only => [:show], :position => 'sidebar'
  #sidebar :user_profile, :if => :user_specified?, :only => [:show], :position => 'sidebar'
  #sidebar :entry_attach_photo, :only => [:new, :create, :edit, :update], :position => 'sidebar'
  sidebar :calendar, :except => [:destroy, :list], :position => 'sidebar'
  #sidebar :adsense_250x250, :except => [:destroy, :new, :create, :edit, :update], :position => 'sidebar'
  
  sidebar :entry_comments, :only => :show, :position => 'footer'
  sidebar :entry_add_comment, :only => :show, :position => 'footer'
  
  verify :method => :post, :only => [:destroy, :create, :update ],
         :redirect_to => { :action => :list }
  verify :only=> :create_comment, :method=> :post, :params=> :comment,
         :redirect_to=> :show

  # GET actions

  def index
    list
    render :action => 'list'
  end

  # list all of an author's entries. optinally establish a journal context.
  # iff there are entries, set the date from the first one  
  def list
    @entries = nil        # compute on-demand
    @entry_pages = nil
    @date = nil
  end
  
  def show
    if @entry
      @comments = nil
      
      record_request(@entry)
      if (logged_in?)
        current_user.set_read_time(@entry)
        if (j = @entry.journal)
          current_user.set_read_time(j)
        end
      end  
    else
      redirect_to :action => 'new'
    end
  end
  
  def new
    if (@entry = find_entry())
      redirect_to :action => 'edit'
    else
      @entry = Entry.new()
      @entry.journal = @journal
      @entry.date = @date
      render :action=> 'new'
    end
  end
  
  # not used: the creation is anscilliary to the entry presentation
  # create and present a new comment for the designated entry.
  # def new_comment
  #  @comment = Comment.new("user_id"=> current_user.id)
  #   @comment.comment = " "
  # end
  
  def edit
  end
  

  # POST actions
  
  def create
    @entry = Entry.new(params[:entry])
    @entry.journal = @journal
    @entry.date = @date
    @journal.updated_at=(Time.now);
    if (@entry.save )
      if ( (Date.today <= @journal.end_date) && !(@journal.save))
        # puts("errors: #{@journal.errors.full_messages}")
        logger.info("can't update journal for entry #{@journal.errors.full_messages}")
      end
      case params[:entry][:state]
      when 'published'
        @entry.publish!()
        @entry.save;
      end
      notify_journal_subscribers(@journal, @entry)      
      flash[:notice] = @date == @journal.start_date ? "Congratulations! You've created your first journal entry." : 'The journal entry was created successfully.'
      redirect_to user_journal_url(:user_id=>@user.id, :journal_id=>@journal.id)
    else
      flash[:error] = 'The journal entry could not be created.'
      logger.info("entry not saved: " + @entry.inspect())
      render :action => 'new'
    end
  end
  
  def create_comment
    # assert the current user as the comment author
    comment_params = (params[:comment] || {}).merge({"user_id"=> current_user.id,
                                                     "created_by"=> current_user.id,
                                                     "updated_by"=> current_user.id})
    @comment = Comment.new(comment_params)
    if (@comment.comment.blank?)
      case (process_entry_subscription(@entry, current_user, params))
      when Journal::SUBSCRIBE
        flash[:notice] = 'Subscription added.'
        redirect_to @entry.url
      when Journal::UNSUBSCRIBE
        flash[:notice] = 'Subscription removed.'
        redirect_to @entry.url
      else
        flash[:error] = 'Please enter a comment.'
        @entry.errors.add('comment', "may not be blank")
        render :action => 'show'
      end
    else
      @comment.comment = markdown(strip_tags(@comment.comment))
      # the journal controls the initial comment state.
      # nb. comments are not state machines
      @comment.state=(@entry.journal.comment_state)
      if (@comment.save())
        @entry.comments << @comment
        date = @entry.date()
        flash[:notice] = 'Comment was successfully saved.'
        begin
          UserNotifier.deliver_comment(@user, current_user, @entry,
                                       strip_tags(@comment.comment)) # remove markdown result
        rescue Exception
          logger.warn("add_comment: deliver_comment exception: #{$!}")
        end
        if ( journal = @entry.journal )
          # notify subscribers to the specific entry
          notify_entry_subscribers(journal, @entry)
          # notify subscribers to the journal as-a-whole
          notify_journal_subscribers(journal, @entry)
          process_entry_subscription(@entry, current_user, params)
        end
        redirect_to @entry.url
      else
        flash[:error] = 'Comment was not saved.'
        logger.info("comment not saved: " + @comment.inspect())
        render :action => 'show'
      end
    end
  end

  def destroy
    logger.info("entry to be destroyed: " + @entry.inspect())
    @entry.destroy
    #logger.info("redirect to: " + url_for(:controller =>"journals", :action => 'show',
    #                                      :user_id=>@user.id(), :journal_id=>@journal.id()))
    #redirect_to :controller =>"journals", :action => 'show',
    #            :user_id=>@user.id(), :journal_id=>@journal.id()
    # logger.info("will redirect to: /users/#{@user.id()}/journals/#{@journal.id()}")
    # redirect to the owner's respective journal
    # user.id is not correct for admins
    redirect_to("/users/#{@journal.owner.id()}/journals/#{@journal.id()}")
  end
  
  # make an assertion about the entry in the entry journal's current context 
  #  {:subject=> {:type=> name, :text=> (text + id)},
  #   :predicate=> {:type=> name, :text=> (text + id)} }
  #   
  def assert
    if (journal = @entry.journal)
      if ( (predicate = intern_query_parameter(params[:predicate])) &&
           (object = intern_query_parameter(params[:object])) )
        @assertion = journal.assert(@entry, predicate, object)
      end
    end
    render_assertion_response(@assertion)
  end
  
  def deny
    if (journal = @entry.journal)
      if ( (predicate = intern_query_parameter(params[:predicate])) &&
           (object = intern_query_parameter(params[:object])) )
        @assertion = journal.deny(@entry, predicate, object)
      end
    end
    render_assertion_response(@assertion)
  end
        
  def subscribe_user
    if (current_user && @entry)
      current_user.assert(@entry, User::SUBSCRIPTION, current_user)
      flash[:notice] = "The comment notification was successfully added."
    end
    redirect_to :back
  end
  
  def unsubscribe_user
    if (current_user && @entry)
      current_user.destroy_assertion(@entry, User::SUBSCRIPTION, current_user)
      flash[:notice] = "The comment notification was successfully turned off."
    end
    redirect_to :back
  end
  
  def update
    if @entry.update_attributes(params[:entry])
      flash[:notice] = 'The journal entry was saved successfully.'
      if params[:entry][:body].blank?
        redirect_to :back
      else
        redirect_to :action => 'show'
      end
    else
      flash[:error] = 'The journal entry could not be saved.'
      logger.info("entry not saved: " + @entry.inspect())
      render :action => 'edit'
    end
  end

  hide_action :breadcrumb_trail, :entry_class, :date
  
  def instance_page_title()
    if (@entry && !(@entry.removed?))
      "'#{@entry.journal.title}': #{@entry.date_formatted}, by #{@entry.journal.owner.login} - #{super()}"
    elsif (@journal && @journal.active?)
      if (owner = @journal.owner)
        "'#{@journal.title}' by #{owner.login} - #{super()}"
      else
        "#{@journal.title} - #{super()}"
      end
    elsif (@user && @user.active?)
      "#{@user.login}: Entries - #{super()}"
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
    if (@entry && !(@entry.removed?))
      case action_name.to_sym()
      when :show
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << [@entry.journal.owner.login, @entry.journal.owner.url]
        trail << [@entry.journal.title, @entry.journal.url]
        trail << @entry.date_formatted
      when :list
        trail << "Entries"
      when :new
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << [@entry.journal.owner.login, @entry.journal.owner.url]
        trail << [@entry.journal.title, @entry.journal.url]
        trail << @entry.date_formatted
      when :edit
        trail << ["People", {:controller=> "users", :action=> :list}]
        trail << [@entry.journal.owner.login, @entry.journal.owner.url]
        trail << [@entry.journal.title, @entry.journal.url]
        trail << [@entry.date_formatted, @entry.url]
        trail << 'Edit'
      end
    else
      # was a list w/o a journal
      trail << "Entries"
    end
    trail
  end
  
  def entry_class(date, context_params = {})
    if (@journal)
      context_entry_class(date, {:journal=> @journal}.merge(context_params))
    else
      ENTRY_CLASS_OK
    end
  end
  
  def date()
    unless @date
      entries = entries()
      if entries.length() > 0
        @date = entries[0].date()
      else
        users_today()
      end
    end
    @date
  end
  
  protected
  
  def notify_journal_subscribers(journal, entry)
    if (journal && entry && Settings.notify_journal_subscribers)
      subscribers = journal.subscribed_users()
      subscribers.each{|u|
        unless (user_is_current_user?(u))
          begin
            UserNotifier.deliver_journal_subscriber_notice(u, journal, entry, self)
          rescue Exception
            logger.info("deliver_journal_subscriber_notice failed: #{$!} : #{u.id}/#{u.login}/#{u.email}")
          end
        end
      }
    end
  end
  
  def notify_entry_subscribers(journal, entry)
    if (journal && entry && Settings.notify_entry_subscribers)
      subscribers = entry.subscribed_users()
      subscribers.each{|u|
        unless (user_is_current_user?(u))
          begin
            UserNotifier.deliver_entry_subscriber_notice(u, journal, entry, self)
          rescue Exception
            logger.info("deliver_entry_subscriber_notice failed: #{$!} : #{u.id}/#{u.login}/#{u.email}")
          end
        end
      }
    end
  end
  
  
  # add or remove a subscriber to the entry upon request
  # 20070124.james  changed assertion context to current_user
  # return indication of effect
  def process_entry_subscription(entry, user, params)
    if (entry && user)
      case param(User::SUBSCRIPTION, Journal::NO_CHANGE, params)
      when Journal::SUBSCRIBE
        # assert checks for and over-writes duplicates
        user.assert(entry, User::SUBSCRIPTION, current_user)
        Journal::SUBSCRIBE
      when Journal::UNSUBSCRIBE
        # conditionally delete
        user.destroy_assertion(entry, User::SUBSCRIPTION, current_user)
        Journal::UNSUBSCRIBE
      else
        nil
      end
    end
  end
  
  # entry page computation differs from the general, in that entries maye be filled and
  # the unscoped list is not constrained to have pictures.
  # 
  def compute_entry_pages(args = {})
    page_size = session_param([:entry_page_size, :page_size], Settings.entry_limit, args) || Entry.count
    page_number = page_number_param([:entry_page, :page], 1, args)
    fill_entries_p = param(:fill_entries, FILL_JOURNAL_ENTRIES, args)
    conditions = []
    
    if (user = @user)
      if ( user.active?)
        if (journal = @journal)
          if ( journal.active? )
            # puts("e_c#c_e_p: args: #{args.inspect}")
            # puts("e_c#c_e_p: params: #{params.inspect}")
            # puts("e_c#c_e_p: session pre: #{session.inspect}")
            entry_sort = (presentation_setting(@journal, :entry_sort, [args, session, current_user, @journal.owner, site_context()]) || {})
            sort_column = entry_sort['column'] || 'date'
            sort_order = entry_sort['order'] || 'DESC'
            @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
            order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
            # puts("e_c#c_e_p: session post: #{session.inspect}")
            # puts("e_c#c_e_p: entry_sort: #{entry_sort.inspect}")
            # puts("e_c#c_e_p: @page_sort_order: #{@page_sort_order.inspect}")
 
            Entry.with_scope(:find=> {:conditions=> (conditions1 = ['journal_id = ?', journal.id()])}) {
              if (fill_entries_p && (user_is_current_user?() || current_user_is_admin?()))
                # optionally fill entries for the author or the admin
                @entries = fill_entries(Entry.find(:all, :order => 'date DESC'), journal)
                extent_count = @entries.length
                @entry_pages = 
                  Paginator.new(self, extent_count, [page_size, extent_count].max, page_number)
                conditions2 = []
              else
                @entry_pages, @entries =
                  ((user_is_current_user?() || current_user_is_admin?()) ?
                   paginate(:entries, :order => order_option,
                                      :per_page => page-size,
                                      :conditions => (conditions2 = ['updated_by = ?', user.id()]) ) :
                   paginate(:entries, :order => order_option,
                                      :per_page => page_size,
                                      :conditions => (conditions2 = ['updated_by = ? && state=?', user.id(), 'published']) ))
              end
            conditions = conditions1 + conditions2
            }    
          else # journal is inactive
            @entries = []
            @entry_pages = Paginator.new(self, 0, 1, 1)
          end   
        else
          # given the user only, it's filling is not done. it would require
          # merging filled sequences from each journal
          entry_sort = (presentation_setting(Entry, :entry_sort, [args, session, current_user, @user, site_context()]) || {})
          sort_column = entry_sort['column'] || 'date'
          sort_order = entry_sort['order'] || 'DESC'
          @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
          order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
          @entry_pages, @entries = paginate(:entries, :conditions => (conditions = ['updated_by = ?', user.id()]),
                                            :order => order_option,
                                            :page=> page_number,
                                            :per_page => page_size)
        end
      else # the user is inactive
        @entries = []
        @entry_pages = Paginator.new(self, 0, 1, 1)
      end
    elsif (journal = @journal)
      if (journal.is-active?)
          entry_sort = (presentation_setting(journal, :entry_sort, [args, session, current_user, journal.owner, site_context()]) || {})
          sort_column = entry_sort['column'] || 'date'
          sort_order = entry_sort['order'] || 'DESC'
        @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
        order_option = "#{@page_sort_order['column']} #{@page_sort_order['order']}"
        @entry_pages, @entries = paginate(:entries, :order => order_option,
                                                    :page=> page_number,
                                                    :per_page => page_size)
      else
        @entries = []
        @entry_pages = Paginator.new(self, 0, 1, 1)
      end
    else
      entry_sort = (presentation_setting(Journal, :entry_sort, [args, session, current_user, site_context()]) || {})
      sort_column = entry_sort['column'] || 'date'
      sort_order = entry_sort['order'] || 'DESC'
      @page_sort_order = {'column' => canonical_sort_column(sort_column), 'order'=> canonical_sort_order(sort_order)}
      order_option = "entries.#{@page_sort_order['column']} #{@page_sort_order['order']}"
      Entry.with_scope(:find=> {:include=> [:journal],
                                :conditions=> (conditions1 = ["journals.scope=? AND journals.state = ? AND entries.state = ?",
                                                              Journal::SCOPE_PUBLIC, Journal::STATE_ACTIVE, Entry::STATE_PUBLISHED])}) {
        @entry_pages, @entries = paginate(:entries, :order => order_option,
                                                    :page=> page_number,
                                                    :per_page => page_size)
      }
    end
    logger.debug("EC#c_e_p: #{args.inspect} admin: #{current_user_is_admin?()} page: #{page_number} x #{page_size} journal: #{@journal ? @journal.id : '-'} user: #{@user ? @user.id : '-'}")
    logger.debug("EC#c_e_p: ? [#{conditions.join(' ')}] x #{order_option}")
    logger.debug("EC#c_e_p: = [#{@entries.map{|i| i.id.to_s}.join(',')}]/#{@entry_pages.page_count}/#{@entry_pages.item_count}")
    
  end
    
  def get_date
    if ( (month = params[:month]) && (day = params[:date]) && (year = params[:year]) )
      @date = "#{month}/#{day}/#{year}".to_date
    else
      @date = users_today
    end
    
    # puts("get_date: date: #{@date}: " + params.inspect())
  end
    
  def restrict_read
    # if no specific journal or the journal is public, ok for any request
    if (@journal == nil || (@journal.scope == User::SCOPE_PUBLIC))
      true
    # otherwise, require authentication
    else
      if (logged_in?)
        # do not restrict admins. otherwise both the owner and members of
        # a franchising group can read
        if (current_user_is_admin?() ||
            (@journal.owner == current_user) ||
            (@journal.groups.any?{|g| g.users.include?(current_user)}))
          true
        else
          permission_denied()
        end
      else
        permission_denied()
      end
    end
  end

  def restrict_write
   # puts("restrict_access: params: #{params.inspect}")
   # puts("journal: #{@journal.inspect}")
   # puts("user: #{@user.inspect}")
   unless (@journal.owner == current_user || current_user_is_admin?)
     permission_denied()
   end
  end
  
  def permission_denied()
    logger.info("[authentication] Permission denied to %s at %s for %s" %
      [(logged_in? ? current_user.login : 'guest'), Time.now, request.request_uri])
    flash[:error] = (logged_in? ? "You do not have access to this." : "That action requires that you first log in.")

    case
    when params[:journal_id]
      redirect_to :controller => 'journals', :action => 'show',:journal_id => params[:journal_id]
    when params[:urlname]
      redirect_to :controller => 'journals', :action => 'show',:urlname => params[:urlname]
    else
      redirect_to home_url
    end
    return false
  end

end
