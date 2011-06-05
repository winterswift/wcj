#!ruby
#
# Word Count Journal class definition for entries
# 
# 2006-11-26  james.anderson  added TextHelper and completion_ratio (adresses #15)

class Entry < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  include Annotation::Annotator
  
  STATE_PUBLISHED = 'published';
  STATE_DRAFT = 'draft';
  STATE_REMOVED = 'removed';
  
  belongs_to :journal
  # belongs_to :user, :through => :journal # not supported
  acts_as_commentable
  file_column :photo,
    #  not used if store dir is set :root_path => "#{RAILS_ROOT}/images/photos/",
    :store_dir => File.join(RAILS_ROOT, 'images','photos'), # #91, this must be static :determine_store_dir,
    :magick => { :versions => { "thumb" => "100x100!", "medium" => "640x480>" } }
  
  before_save :filter_body

  validates_presence_of :journal_id, :date, :body
  validates_uniqueness_of :date, :scope => :journal_id
  def validate
     # puts("entry.validate: date: " + date.to_s())
     # puts("entry.validate: sdate: " + journal.start_date.to_s() + "?" + (date < journal.start_date).to_s())
     # puts("entry.validate: edate: " + journal.end_date.to_s() + "?" + (date > journal.end_date).to_s())
     if date < journal.start_date || date > journal.end_date
       errors.add_to_base "The date must be between the start and end date of your journal."
     end
  end
  
  # State handling
  acts_as_state_machine :initial => :draft
  
  state :draft
  state :published, :enter => :do_publish
  state :removed, :after=> :do_remove
  state :suspended
  
  event :publish do
    transitions :to => :published, :from => :draft
  end

  event :remove do
    transitions :to => :removed, :from => [:draft, :published, :suspended]
  end
  
  event :suspend do
    transitions :to => :suspended, :from => :published
  end
  
  def do_publish
    # Do something
  end
  
  # to remove an entry means
  # - clear the journal
  # - blank the text
  def do_remove()
    logger.info("removing entry #{self.id}:")
    self.journal = nil
    self.body = ""
    self.save_with_validation(false)
    logger.info("removed entry: #{self.id}:")
  end
  
  
  # permit assertions about entries
  include Annotation::Annotatable
  
  # Custom functions
  def url
#    "/users/#{journal.user.login}/#{journal.urlname}/#{date.strftime("%Y/%m/%d")}"
    if (journal && journal.user)
      "/users/#{journal.user.id}/journals/#{journal.id}/#{date.strftime("%Y/%m/%d")}"
    else
      "/entries/#{id}"
    end
  end
  
  def url_hash
    if (journal && journal.user)
      {:controller => 'entries', :user_id => user.id.to_s, :journal_id => journal.id.to_s, :year => date.strftime("%Y"), :month => date.strftime("%m"), :date => date.strftime("%d")}
    else
      {:controller => 'entries', :entry_id => id }
    end
  end
  
  def session_id()
    "#{self.class.name}/#{self.id}"
  end
  
  def owner
    self.user()
  end
  
  def user
    journal ? journal.owner : nil
  end
  
  def active?()
    (removed? ? false : (journal ? journal.active? : false))
  end
  
  def suspended?()
    (journal ? journal.suspended? : false)
  end

  def determine_store_dir
    # "#{journal.user.login}/#{journal.urlname}/#{date.to_s}"
    # "#{journal.user.id}/#{journal.id}/#{id}" no object id
    "#{journal.user.id}/#{journal.id}" 
  end
  
  def date_formatted
    date.to_formatted_s :long
  end
  
  def excerpt(length = 20)
    if ( body_filtered.blank? )
      ""
    else
      strip_tags(body_filtered).split[0...length].join(' ')
    end 
  end
  
  def words(value = body_filtered)
    Entry::words(strip_tags(value || ""))
  end
  
  def self.words(value)
    if (nil == value || "" == value)
      0
    else
      # first eliminate quotations, then any non alphathen compress whitespace, then split at single spaces
      compressible_whitespace = /\s+/;
      removable_non_alpha = /[^\w\s]+/;
      fillable_non_alpha = /([^\w\s]\s)|(\s[^\w\s])|[,;+]/;
      value = value.gsub(fillable_non_alpha, ' ')
      value = value.gsub(removable_non_alpha, '')
      value = value.gsub(compressible_whitespace,' ');
      value.split(' ').length
    end
  end
  
  def self.word_count()
    Entry.find_by_sql("SELECT body_filtered FROM entries").inject(0){|count, entry| count + entry.words }
  end
  
  def words_required
    self.journal.initial_count + [(date - journal.start_date), 0].max
  end
  
  def completion_ratio
    # puts("completion: #{Float(words ? words : 0) / Float(words_required())} for #{self.inspect()}")
    Float(words || 0) / Float(words_required)
  end
  
  def subscribed_users()
    assertions_that(self, User::SUBSCRIPTION, :all, nil ).map{|i| (i.kind_of?(User) && i.active?()) ? i : nil }.compact
  end
  
  def previous_entry(state = STATE_PUBLISHED)
    if (journal)
      (state ?
       Entry.find_by_sql(["SELECT * FROM entries WHERE (journal_id = ? AND date < ? AND state = ?) ORDER BY date desc LIMIT 1",
                          journal.id, self.date, state]) :
       Entry.find_by_sql(["SELECT * FROM entries WHERE (journal_id = ? AND date < ?) ORDER BY date desc LIMIT 1",
                          journal.id, self.date]) ).first
                        
    else
      nil
    end
  end
  
  def next_entry(state = STATE_PUBLISHED)
    if (journal)
      (state ?
       Entry.find_by_sql(["SELECT * FROM entries WHERE (journal_id = ? AND date > ? AND state = ?) ORDER BY date asc LIMIT 1",
                          journal.id, self.date, state]) :
       Entry.find_by_sql(["SELECT * FROM entries WHERE (journal_id = ? AND date > ?) ORDER BY date asc LIMIT 1",
                          journal.id, self.date]) ).first
    else
      nil
    end
  end
  
  # graph methods
  def graph_attributes(grapher)
    { 'URL'=> self.url(),
      'label'=> (date ? date.to_s : "#{self.class.name}/#{self.id}"),
      'shape' => 'rectangle' }
  end
  
  def build_graph(grapher)
    grapher.debug("Entry#build_graph(#{self}/#{self.id})")
    grapher.graph_edge(self.journal(), self)
    self.comments.each{|i| grapher.graph_edge(self, i) }
    super(grapher)
    self
  end
  
  
  protected
  
  def filter_body
    if body.blank?
      self.body_filtered= ""
    else
      # puts(BlueCloth::new(body).to_s)
      # self.body_filtered=(BlueCloth::new(body).to_html)
      self.body_filtered=(markdown(strip_tags(body)))
    end
  end
  
end
