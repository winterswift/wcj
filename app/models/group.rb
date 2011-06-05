#!ruby
#
# Word Count Journal class definition for groups
# 
# 2006-11-15  james.anderson  url designates by id/id rathern than by login/urlname
#   relocated find_instance method from application controller

VERSIONS[__FILE__] = "$Id: group.rb 829 2007-01-31 02:30:45Z james $"

class Group < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  include Annotation::Annotator

  SCOPE_PUBLIC = 'public';
  SCOPE_PRIVATE = 'private';
  SCOPE_GROUP = 'group';
  
  STATE_ACTIVE = 'active'
  STATE_SUSPENDED = 'suspended'
  STATE_REMOVED = 'removed';

  class NotFoundError < NameError
  end

  acts_as_urlnameable :title, :overwrite=>true, :validate => false
  
  # these muck up the persistent description attribute
  # attr_accessor :description
  # attr_accessor :scope
  belongs_to :owner, :class_name => 'User', :foreign_key => 'user_id'
  has_and_belongs_to_many :users
  has_and_belongs_to_many :journals
  before_save :filter_description
  validates_presence_of :title, :description
  validates_uniqueness_of :title
  
  # State handling
  acts_as_state_machine :initial => :active
  state :active
  state :suspended
  state :removed, :after=> :do_remove
  
  event :remove do
    transitions :to => :removed, :from => [:active, :pending, :suspended]
  end
  
  event :suspend do
    transitions :to => :suspended, :from => :active
  end
  
  # to remove a groups means
  # - clear the user
  # - replace the title
  # - retract franchised journals
  # - retire member users
  def do_remove()
    logger.info("removing group #{self.id}:")
    self.owner = nil
    self.title = "#{self.id} removed #{Time.now.utc.strftime('%Y%m%dT%H%M%S')}Z"
    self.description = ""
    logger.info("retracting journals: #{self.journals.map{|i| i.id}.join(',')}")
    self.journals.clear
    logger.info("retiring members: #{self.users.map{|i| i.id}.join(',')}")
    self.users.clear
    self.save_with_validation(false)
    logger.info("removed group: #{self.id}:")
  end

  # permit assertions about groups
  include Annotation::Annotatable

  # Group methods
  # 
  # Return the Group instance designated by id, title, or urlname as key.
  # The id serves as a global designator, while the title, and thus the
  # urlname, are valid in the context of a user only.
  # The argument can be a string, in which it is interpreted as the id, or
  # it can be a keyhash, in which case the precedence is id, title, urlname.
  # The default argument is the current params keyhash
  # If no instance is found - whether because there is no user context, or no
  # journal matches, the :if_does_not_exist param specifies either nil or error.
  
  def self.find_instance(args = params)
    designator = nil
    dimension = :nil
    result = nil
    user = nil
 
    logger.debug("Group.find_instance(" + args.inspect() + ")");
    args ||= {}
    
    case
    when (designator = (args.kind_of?(String) ? args : (args[:group_id] || args[:id])))
      dimension=:id
      result = Group.find_by_id(designator)
    when (designator = args[dimension=:title])
      if (user = args[:user])
        result = user.find_journal_by_title(designator)
      else
        result = Group.find_all_by_title(designator)
      end
    when (designator = args[dimension=:urlname])
      if (user = args[:user])
        result = user.find_journal_by_urlname(designator)
      else
        result = Group.find_all_by_urlname(designator)
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
                                "group not defined [context: #{user.login()}/#{dimension}]: #{designator}" :
                                "group not defined [context: #{dimension}]: #{designator}"),
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
 
    logger.debug("Group.find_instance(...) x " + dimension.to_s() + " => " + result.inspect());
    return result
  end

  # return an array of groups which grant the user access to a journal
  def self.user_journal_groups(user, journal)
    if (user && journal)
         Group.find(:all, :include=> [:users, :journals],
                          :conditions=> ["users.id = ? AND journals.id = ?", user.id, journal.id])
    else
      []
    end
  end
  
  def url
#    "/groups/#{urlname}"
    # it appears necessary to force update for the owner
    # it is also possible for a group to lose its owner
    if (o = owner(true))
      "/users/#{o.id}/groups/#{id}"
    else
      logger.warn("group missing owner: [#{id}]:#{self.inspect}")
      "/groups/#{id}"
    end
  end
  
  def url_hash
    {:controller => 'groups', :user_id => (owner ? owner.id.to_s : nil), :group_id => id.to_s}
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
  
  def Group.create (params)
    logger.info("group.create: " + params.to_s)
    group = new(params[:group])
    if @group.save()
      logger.info("group.save:: " + @group.to_s)
      return (group)
    else
      logger.info("not saved.")
      return ( nil )
    end
  end
  
  def filter_description
    self.description = strip_tags(self.description)
  end
  
  # graph methods
  def graph_attributes(grapher)
    { 'URL'=> self.url(),
      'label'=> (title.blank? ? "#{self.class.name}/#{self.id}" : title) }
  end
  
  def build_graph(grapher)
    grapher.debug("Group#build_graph(#{self}/#{self.id})")
    grapher.graph_edge(self.owner(), self, {'label'=> 'owner', 'color' => 'blue'})
    self.journals.each{|i| grapher.graph_edge(self , i, 'label'=> 'franchises') }
    super(grapher)
    self
  end
  
  
  protected
  
  module DeletableError
  def delete(key)
    @errors.delete(key.to_s)
  end
  end
  
  
  def validate()
    super()
   class << errors
      include DeletableError
    end
    errors.delete('urlname') # duplicates the title error
    
  end
  
end
