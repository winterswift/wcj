#!ruby
#
# c 2006 makalumedia
# 
# Entry class model tests
# 
# 2006-11-16  james.anderson
# 2006-11-26  james.anderson  entry date class  (adresses #15)
# 2006-12-19  james.anderson  controller does not prebind @entries, which
#   means, it is not visible to assigns
# 2007-01-02  james.anderson  changed test_list_author for additions to
#  journal's entries

require File.dirname(__FILE__) + '/../test_helper'
require 'entries_controller'

# Re-raise errors caught by the controller.
class EntriesController; def rescue_action(e) raise e end; end

class EntriesControllerTest < Test::Unit::TestCase
  fixtures :users, :journals, :entries

  def setup
    @controller = EntriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # test creation operation
  # - iff an entry exists for the date, the operation fails, and the edit continues
  # - if the entry is valid, it is saved and the response redirects
  def test_create
    num_entries = Entry.count
    journal = Journal.find(1)
    latest_entry = journal.entries[0]
    bad_date = journal.end_date + 1
    good_date = latest_entry.date + 1
    
    # puts("journal(#{journal.owner.login}): [#{journal.start_date}-#{journal.end_date}], date: #{good_date}|#{bad_date}")
    
    login_as "anauthor"
    post :create, :entry => {:body=>"functional test text."},
                  :user_id=>"1", :journal_id=>"1",
                  :year=>bad_date.year.to_s, :month=>bad_date.month.to_s, :date=>bad_date.day.to_s
    # puts(@response.body())
    assert_response 200
    # puts("flash[]: #{flash[:error]}")
    assert flash[:error] =~ /.*not be created.*/
    assert_equal num_entries, Entry.count

    post :create, :entry => {:body=>"functional test text."},
                  :user_id=>"1", :journal_id=>"1",
                  :year=>good_date.year.to_s, :month=>good_date.month.to_s, :date=>good_date.day.to_s
    # puts("create request: " + @request.inspect())
    # puts(@response.body())
    # puts("flash[]: #{flash[:notice]}")
    assert flash[:notice] =~ /.*was created.*/
    assert_response :redirect
    # does not work, as the test fails when redirect was to a literal url
    # assert_redirected_to :controller => 'journals', :action => 'show'
    assert_equal num_entries + 1, Entry.count
  end
  
  # test that the comment text and title are as specified
  # test that the user/updated/created ids are all the authenticated user
  def test_create_comment
    comment_text = "a comment"
    comment_title = "a title"
    login_as("reader1")
    current_user_id = @request.session[:user]
    entry = Entry.find(1)
    before_count = entry.comments().length()
    date= entry.date
    
    post :create_comment, :comment=> {:comment=> comment_text, :title=> comment_title,
                                      :user_id=> '0',
                                      :created_by=> '0', :updated_by=> '0'},
                                      :user_id=>entry.journal.owner.id.to_s, :journal_id=>entry.journal.id.to_s,
                                      :year=>date.year.to_s, :month=>date.month.to_s, :date=>date.day.to_s
    entry = Entry.find(1)
    comment = entry.comments()[0]
    # puts("comment: #{comment.inspect()}")
    assert_equal before_count + 1, entry.comments().length()
    assert assigns(:entry)
    assert assigns(:comment)
    assert_equal("<p>" + comment_text + "</p>", comment.comment) # markdown
    assert_equal(comment_title, comment.title)
    assert_equal(current_user_id, comment.user_id)
    assert_equal(current_user_id, comment.created_by)
    assert_equal(current_user_id, comment.updated_by)
  end

  # an attempt to delete as a non-admin user; should be forbidden
  # the permisson implemention can redirect only
  def test_destroy_as_author_302
    num_entries = Entry.count
    assert_not_nil Entry.find(1)
    
    login_as "anauthor"
    post :destroy, :user_id => 1, :journal_id=>1,
                   :year=>"2000", :month=>"11", :date=>"01"
    assert_response 302 
    assert_equal num_entries, Entry.count
    end

  # first, try to delete a non-existent entry; should be not-found
  def test_destroy_as_admin_404
    num_entries = Entry.count
    date = 20.days.ago  # 10 is the limit
    assert_raise(ActiveRecord::RecordNotFound) {
      Journal.find(0)
    } 
    
    login_as "anadmin"
    # puts("loggedin: ")
    post :destroy, :user_id => 1, :journal_id=>0,
                   :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    # puts("response: " + @response.body())
    assert_response 404
    assert_equal num_entries, Entry.count
    end
    
 # then, successful deletion should redirect to the respective journal
  def test_destroy_as_admin_200
    num_entries = Entry.count
    date = 10.days.ago
    
    login_as "anadmin"
    post :destroy, :user_id => 1, :journal_id=>1,
                   :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    # this fails as assert_redirected_to expects response.redirected_to
    # to be a hasg, but, in this case, it is a string
    # assert_redirected_to({:controller=>'journal', :action => 'show'})
    # puts("response: " + @response.redirected_to)
    assert_equal "http://test.host/users/1/journals/1", @response.redirected_to()
    assert_raise(ActiveRecord::RecordNotFound) {
      Entry.find(1)
    } 
  end

  def test_edit
    date = 10.days.ago
    
    login_as "anauthor"
    get :edit, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert_response :success
    assert_template 'edit'
    # puts(assigns.inspect())
    assert_not_nil assigns(:entry)
    assert assigns(:entry).valid?
  end

  # test the entry list page:
  # - if admin, it should include edit/destroy links
  # - if the author but no journal is supplied, it should succeed
  # - if the author is not found, it should 404
  # - non-admin redirects
  def test_list_guest
    # first, w/o authentication
    get :list, :user_id=>"1", :journal_id=>"1"
    assert_response 302
    # assert_template 'list'
    # assert_not_nil @controller.entries()
    # assert_no_tag(:parent=>{:tag=>'td'}, :tag=>'a', :content=>"Edit")
  end
  
  
  def test_list_author
    # then as the entries' author
    login_as "anadmin"
    get :list, :user_id=>"1", :journal_id=>"1"
    assert_response :success
    # puts(@response.body())
    # puts("entries #{@controller.entries()}")
    assert_tag(:parent=>{:tag=>'td'}, :tag=>'a', :content=>"Edit")
    assert_tag(:parent=>{:tag=>'td'}, :tag=>'a', :content=>"Destroy")
    assert_equal(11, @controller.entries().length)
    # @controller.entries().map{|e| puts("date: #{e.date.to_s}, new: #{e.new_record?}")}
    assert_equal(2, @controller.entries().map{|e| e.new_record?}.nitems)
  end
  
  def test_list_author_no_journal
    login_as "anadmin"
    get :list, :user_id=>"1"
    assert_response :success
    # "2006-11-05" entry is missing
    assert_equal(0, @controller.entries().map{|e| e.new_record?}.nitems)
  end
  
  def test_list_author_unknown
    # then, for an unknown author
    login_as "anadmin"
    get :list, :user_id=>"0"
    # puts(@response.body())
    assert_response 404    
  end

  def test_new
    date = 10.days.ago
    
    login_as "anauthor"

    # an extant entry redirects to edit
    get :new, :user_id=>"1", :journal_id=>"1",
              :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    # puts("new request: " + @request.inspect())
    assert_response 302
    #? rendered_file in response is nil assert_template 'edit'

    # a non-existent entry is a real new (see entries fixture)
    date = 6.days.ago
    get :new, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    # puts("new request: " + @request.inspect())
    # puts("new response: " + @response.rendered_file().to_s)
    assert_response :success
    #? rendered_file in response is nil assert_template 'new'
    assert_not_nil assigns(:entry)
  end

  # test that the presented comment text and title are as specified
  # test that the presented user id is the authenticated user
  # not used: see action in EntriesController
  # 
#  def test_new_comment
#    date = 10.days.ago
#    login_as("reader1")
#    current_user_id = @request.session[:user]
#    
#    get :new_comment, :user_id=>'1', :journal_id=>'1',
#                      :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
#    assert_response :success
#    assert(entry = assigns(:entry))
#    assert(comment = assigns(:comment))
#    assert_equal(current_user_id, comment.user_id)
#  end

  # test that the presented comment text and title are as specified
  # test that the presented user id is the authenticated user
  def test_new_comment_403
    date = 10.days.ago
    # no login
    
    get :new_comment, :user_id=>'1', :journal_id=>'1',
                      :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert_redirected_to :action => 'show'
  end
  
  def test_show
    date = 10.days.ago
    get :show, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:entry)
    assert assigns(:entry).valid?
  end

  def test_title
    date = 10.days.ago
    get :show, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert_response :success
    assert entry = assigns(:entry)
    assert_tag(:tag => "title", :parent => { :tag => "head" },
               :content=> Regexp.new("'#{entry.journal.title}': #{entry.date_formatted}, by #{entry.journal.owner.login} - #{Settings.page_title}"))
  end
  
  def test_update
    date = 10.days.ago
    login_as "anauthor"
    post :update, :entry => {:body=>"replacement test text."},
                  :user_id=>"1", :journal_id=>"1",
                  :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert_redirected_to :action => 'show'
  end

  def test_entry_class_below()
    date = 5.days.ago
    get :show, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert j = assigns(:journal)
    assert e = assigns(:entry)
    # puts("entry(#{e.id}): #{e.inspect()} words: #{e.words()}/#{e.words_required()}/#{e.completion_ratio()} #{e.completion_ratio() > 1.0}")
    # puts("class: #{@controller.entry_class(e.date())}")
    assert EntryCalendarController::ENTRY_CLASS_BELOW == @controller.entry_class(e.date())
  end
  
  def test_entry_class_ok()
    date = 8.days.ago
    get :show, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert j = assigns(:journal)
    assert e = assigns(:entry)
    # puts("entry(#{e.id}): #{e.inspect()} words: #{e.words()}/#{e.words_required()}/#{e.completion_ratio()} #{e.completion_ratio() > 1.0}")
    assert EntryCalendarController::ENTRY_CLASS_OK == @controller.entry_class(e.date())
  end
  
  def test_entry_class_above()
    date = 10.days.ago
    get :show, :user_id=>"1", :journal_id=>"1",
               :year=> date.year.to_s, :month=> date.month.to_s, :date=> date.day.to_s
    assert j = assigns(:journal)
    assert e = assigns(:entry)
    # puts("entry(#{e.id}): #{e.inspect()} words: #{e.words()}/#{e.words_required()}/#{e.completion_ratio()} #{e.completion_ratio() > 1.0}")
    assert EntryCalendarController::ENTRY_CLASS_ABOVE == @controller.entry_class(e.date())
  end

  def test_format_time
    time = Time.utc(2006, 1, 1, 12, 0, 0)
    assert_equal("2006-01-01T12:00:00", @controller.format_time(time))
    assert_equal("20060101T120000", @controller.format_time(time, :format=> "%Y%m%dT%H%M%S"))
    assert_equal("2006-01-01T07:00:00", @controller.format_time(time, :time_zone=> TzinfoTimezone.new("America/New_York")))
    assert_equal("2006-01-01T13:00:00", @controller.format_time(time, :time_zone=> TzinfoTimezone.new("Europe/Berlin")))
  end

end
