#!ruby
#
# Word Count Journal class definition for journals
# 
# 2006-11-15  james.anderson  url designates by id/id rathern than by login/urlname
# 2006-12-18  james.anderson  initial count column
# 
class Journal < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  include Annotation::Annotator

  SITE_JOURNAL_TITLE = "WCJ Journal";
  
  SCOPE_PUBLIC = 'public';
  SCOPE_PRIVATE = 'private';
  SCOPE_GROUP = 'group';

  STATE_ACTIVE = 'active';
  STATE_SUSPENDED = 'suspended';
  
  SUBSCRIBE = 'subscribe';
  UNSUBSCRIBE = 'unsubscribe';
  NO_CHANGE = 'no_change';
  
  @@permit_retroactive_start_date = nil;
  @@permit_retroactive_end_date = nil;
  @@duration_maximum = Settings.journal_duration_maximum || 720;
  
  class NotFoundError < NameError
  end
  
  # it is not clear how the :validate=> false is supposed to work, since the
  # initialization has a clause
  #       :validate           => (options[:validate] || :class),
  # to extract the validate option, which will then default to :class, while the
  # validation code requires logical false to disable validation ...
  # thus, see the validate specialization below
  acts_as_urlnameable :title, :overwrite => true, :validate => false # :owner
  
  # mucks up persistent attributs
  # attr_accessor :scope
  belongs_to :owner, :class_name => 'User', :foreign_key => 'user_id'
  has_and_belongs_to_many :groups
  has_many :entries, :order => 'date DESC', :dependent => :destroy do
    def drafts
      find(:all, :conditions => ['state = ?', 'draft'])
    end
  end
  has_many :comments, :through => :entries
  has_many :users, :through=> :groups
  before_save :filter_description
  validates_presence_of :user_id, :title, :start_date, :end_date, :owner
  validates_uniqueness_of :title, :scope => :user_id
  
  # State handling
  acts_as_state_machine :initial => :active
  state :active
  state :suspended
  state :removed, :after=> :do_remove

  event :remove do
    transitions :to => :removed, :from => [:active, :suspended]
  end
  
  event :suspend do
    transitions :to => :suspended, :from => :active
  end
        
  # to remove a journal means to
  # - clear the user
  # - replace the title
  # - blank the description
  # - remove the entries
  # - retract any franchises
  def do_remove()
    logger.info("removing journal: #{self.id}:")
    self.user = nil
    self[:user_id] = nil
    self.title = "#{self.id} removed #{Time.now.utc.strftime('%Y%m%dT%H%M%S')}Z"
    self.description = ""
    logger.info("removing entries: #{self.entries.map{|i| i.id}.join(',')}")
    self.entries.each{|e| e.remove! } # leave instance list intact, but that's ephemeral
    logger.info("retracting from groups: #{self.groups.map{|i| i.id}.join(',')}")
    self.groups.clear
    self.save_with_validation(false) # no user
    journal = Journal.find(self.id)
    logger.info("removed journal: #{self.id}:")
  end


  # Journal methods
  # 
  # Return the Journal instance designated by id, title, or urlname as key.
  # The id serves as a global designator, while the title, and thus the
  # urlname, are valid in the context of a user only.
  # The argument can be a string, in which it is interpreted as the id, or
  # it can be a keyhash, in which case the precedence is id, title, urlname.
  # The default argument is the current params keyhash
  # If no instance is found - whether because there is no user context, or no
  # journal matches, the :if_does_not_exist param specifies either nil or error.
  
  def self.permit_retroactive_start_date?()
    if ( nil == @@permit_retroactive_start_date )
      @@permit_retroactive_start_date = Settings.permit_retroactive_start_date || true;
    else
      @@permit_retroactive_start_date
    end
  end
  
  def self.permit_retroactive_end_date?()
    if ( nil == @@permit_retroactive_end_date )
      @@permit_retroactive_end_date = Settings.permit_retroactive_end_date || false;
    else
      @@permit_retroactive_end_date
    end
  end
  
  def permit_retroactive_start_date?()
    Journal::permit_retroactive_start_date?()
  end
  
  def permit_retroactive_end_date?()
    Journal::permit_retroactive_end_date?()
  end
  
  def self.find_instance(args = params)
    designator = nil
    dimension = :nil
    result = nil
    user = nil
 
    logger.debug("Journal.find_instance(" + args.inspect() + ")");
    args ||= {}
    
    case
    when (designator = (args.kind_of?(String) ? args : (args[:journal_id] || args[:id])))
      dimension=:id
      result = Journal.find_by_id(designator)
    when (designator = args[dimension=:title])
      if (user = args[:user])
        result = user.find_journal_by_title(designator)
      else
        result = Journal.find_all_by_title(designator)
      end
    when (designator = args[dimension=:urlname])
      if (user = args[:user])
        result = user.find_journal_by_urlname(designator)
      else
        result = Journal.find_all_by_urlname(designator)
      end
    when (args.fetch(:if_does_not_exist, :error) == nil)
       return nil   
    else
      fail(ArgumentError, "id, title, or urlname required in: " + args.inspect());
    end
    
    case
    ## control success
    when (result == nil || result == [])
      case (args.fetch(:if_does_not_exist, :error))
      when :error
        fail(NotFoundError.new((user ?
                                "journal not defined [context: #{user.login()}/#{dimension}]: #{designator}" :
                                "journal not defined [context: #{dimension}]: #{designator}"),
                               designator))
      when nil
        result = nil
      else
        fail(ArgumentError, "invalid :if_does_not_exist")
      end
    ## extract singleton sequence
    when (result.kind_of?(Array) && result.length == 1)
      result = result[0];
    end
 
    logger.debug("Journal.find_instance(...) x " + dimension.to_s() + " => " + result.inspect());
    return result
  end

  def self.find_unread_instances(criteria, collection)
    case criteria
    when User
      # collect the journals which the user want to check,
      # examine each to see if it has been modified since read
      modified_journals = []
      case
      when (collection.respond_to?(:each))
        collection.each{|j|
          if ( (last_read = criteria.read_time(j)) &&
               (last_read < j.updated_at) )
            modified_journals << j
          end
        }
      when (collection.respond_to?(:find))
        collection.find(:all).each{|j|
          if ( (last_read = criteria.read_time(j)) &&
               (last_read < j.updated_at) )
            modified_journals << j
          end
        }
      end
      modified_journals     
    when DateTime
      self.find(:all, :conditions=> ["updated_at > ?", criteria])
    else
      []
    end
  end
  
  def group_ids()
    groups.map{|g| g.id}
  end
  
  def group_ids=(ids)
    # puts("groups_ids=(#{ids})")
    case ids
    when Array
      id_groups = Group.find(ids)
    when Integer, String
      id_groups= [Group.find(ids)]
    else
      fail(ArgumentError, "invalid group designators: #{ids}")
    end
    # puts("id_groups: (#{id_groups.map{|g| g.id}.join(',')}")
    
    if (id_groups.all?{|g| g.users.include?(self.owner)})
      self.groups.clear()
      id_groups.map{|g| self.groups << g}
      id_groups
    else
      fail(ArgumentError, "group permission denied: #{ids}")
      nil
    end
  end
  
  def url
#    "/users/#{user.login}/#{urlname}"
    
    if (o = owner(true))
      "/users/#{o.id}/journals/#{id}"
    else
      logger.warn("journal missing owner: [#{id}]:#{self.inspect}")
      "/journals/#{id}"
    end
  end
  
  def url_hash
    {:controller => 'journals', :user_id => (owner ? owner.id.to_s : nil), :journal_id => id.to_s}
  end
  
  def session_id()
    "#{self.class.name}/#{self.id}"
  end
  
  def is_public?()
    SCOPE_PUBLIC == self.scope
  end
  
  def is_private?()
    SCOPE_PRIVATE == self.scope
  end
 
  # compute the number of words so far in the journal
  # limit contribution of a given entry to its maximum count
  def words()
    def entry_journal_words(entry)
      # puts("entry: #{entry}: #{entry.words}/#{entry.words_required} '#{entry.strip_tags(entry.body_filtered).split}")
      [entry.words_required, entry.words].min
    end
    
    self.entries.inject(0){|sum, e|
     # puts("sum: #{sum}, e: #{e}, w: #{entry_journal_words(e)}")
     sum + entry_journal_words(e)
    }
  end
  
  def words_total()    
    self.entries.inject(0){|sum, e| sum + e.words }
  end
  
  def days()
    [0, (self.end_date - self.start_date)+1].max
  end
  
  def running_days()
    effective_end_date = [(owner ? owner.today : Date.today), self.end_date].min
    [0, (effective_end_date - self.start_date)+1].max
  end
  
  def entry_days()
    [0, self.entries.inject(0){|sum, e|
      ( (e.words > 0 && (e.state == 'published')) ? sum + 1 : sum)}].max
  end
  
  
  def words_required()
    base = initial_count()
    (base..(days()+(base - 1))).inject{|sum, i| sum + i}
  end

  def running_words_required()
    base = initial_count()
    (base..(running_days()+(base - 1))).inject{|sum, i| sum + i}
  end
  
  # for compatibility
  def percent_complete
    completion_ratio()
  end

  def completion_ratio
    # puts("completion: #{Float(words ? words : 0) / Float(words_required())} for #{self.inspect()}")
    Float(words || 0) / Float(words_required)
  end

  def running_completion_ratio
    # puts("completion: #{Float(words ? words : 0) / Float(words_required())} for #{self.inspect()}")
    Float(words || 0) / Float(running_words_required)
  end

  def last_updated
    entry = self.entries.first
    entry.updated_at unless entry.blank?
  end
  
  def overdue?
    overdue_days() > 0
  end

  def overdue_days
    # give the author a day to write the entry
    (running_days - 1) - entry_days
  end

  # deprecated, but still used in views
  def user()
    owner()
  end
  
  # deprecated, but still used un views
  def user=(u)
    owner=(u)
  end
  
  def today()
    (owner ? owner.today() : Date.today)
  end

  def subscribed_users()
    assertions_that(self, User::SUBSCRIPTION, :all, nil).map{|i| (i.kind_of?(User) && i.active?()) ? i : nil }.compact()
  end
  
  def readers()
    annotators_that(self, :read_time, :all).map{|i|
      (i.kind_of?(User) && i.active?() && i.is_public?()) ? i : nil }.compact().uniq()
  end
  
  
  def entry_sort()
    assertions_that('Entry', :sort, :first) || {}
  end
  
  def entry_sort=(sort)
    case
    when nil == sort
      deny('Entry', :sort, nil)
    when sort.kind_of?(Hash)
      assert('Entry', :sort, sort)
    else
      fail(ArgumentError, "invalid entry sort hash: #{sort}.")
    end
  end
  
  # graph methods
  def graph_attributes(grapher)
    { 'URL' => self.url(),
      'label' => (title.blank? ? "#{self.class.name}/#{self.id}" : title),
      'shape' => 'rectangle' }
  end
  
  def build_graph(grapher)
    grapher.debug("Journal#build_graph(#{self}/#{self.id})")
    grapher.graph_edge(self.owner(), self, {'label'=> 'author', 'color' => 'blue'})
    self.entries.each{|i| grapher.graph_edge(self, i) }
    super(grapher)
    self
  end

  
  protected
  
  def validate_on_create()
    super()
    if start_date && owner
      unless ( permit_retroactive_start_date?() ?
               start_date.year >= owner.today.year :
               start_date >= owner.today )
        errors.add("start_date", "is in the past.")
      end
      if end_date
        unless ( end_date >= start_date )
          errors.add("end_date", "cannot preceed the start date.")
        end
        unless ( permit_retroactive_end_date?() || end_date >= owner.today )
          errors.add("end_date", "is in the past.")
        end
      else
        errors.add("end_date", "is missing.")
      end
    else
      unless ( errors[:start_date] || start_date )
        errors.add("start_date", "is missing.")
      end
      unless ( errors[:owner] || owner )
        errors.add("owner", "is missing.")
      end
    end
  end
  
  def validate_on_update()
    super()
    if start_date # the start date should not have been allowed to change
    else
      errors.add("start_date", "is missing.")
    end
    if end_date
      unless ( end_date >= start_date )
        errors.add("end_date", "cannot preceed the start date.")
      end
      if (end_date <= owner.today)
        unless ( (raw_date = self.end_date_before_type_cast && end_date.to_s == raw_date) ||
                  permit_retroactive_end_date?() )
          errors.add("end_date", "is in the past.")
        end
      end
    else
      unless ( errors[:end_date] )
        errors.add("end_date", "is missing.")
      end
    end
  end
  
  module DeletableError
  def delete(key)
    @errors.delete(key.to_s)
  end
  end
  
  def validate()
    super()
    if (end_date && start_date)
      unless ( ((end_date - start_date) < @@duration_maximum) ||
               (self.owner && self.owner.is_admin?) )
        errors.add("end_date", "cannot be more than {@@duration_maximum -1} days after the start date.")
      end
    end
    unless ((value = initial_count).kind_of?(Integer) && value > 0)
      errors.add("initial_count", 'is not a positive integer.')
    end
    class << errors
      include DeletableError
    end
    errors.delete('urlname') # duplicates the title error
  end
  
  def filter_description
    self.description = strip_tags(self.description || "")
    self.title = strip_tags(self.title || "")
  end
  
end

