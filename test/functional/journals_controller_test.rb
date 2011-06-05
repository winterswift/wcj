#!ruby
#
# c 2006 makalumedia
# 
# Journal class functional tests
# 
# 2006-11-20  james.anderson
# 

require File.dirname(__FILE__) + '/../test_helper'
require 'journals_controller'

# Re-raise errors caught by the controller.
class JournalsController; def rescue_action(e) raise e end; end

class JournalsControllerTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :groups_users, :users

  def setup
    @controller = JournalsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # test creation invalid data
  # todo: duplicate title, unauthorized user, duplicate but different user
  def test_create_invalid_redirect
    login_as "anauthor"
    num_journals = Journal.count

    # w/o data, the save fails and an edit page is returned.
    post :create, :journal => {}, :user_id=> 1
    assert_response 200
    assert_template 'new'
    assert_equal num_journals, Journal.count
    end

  # a successful save with valid data redirects to the entry edit if in temporal range
  def test_create_valid_redirect_to_edit_WCJ_CJP_N02
    login_as "anauthor"
    num_journals = Journal.count
    start_date = Date.today
    end_date = 10.days.from_now
    post :create, :journal => {:title=> "test journal",
                               :scope=> User::SCOPE_PUBLIC,
                               :description=> "to introduce the test journal",
                               :start_date=> start_date.to_s,
                               :end_date=> end_date.to_s},
                  :user_id=> 1
    # puts("test_create_valid_redirect_to_edit_WCJ_CJP_N02 flash: #{flash.inspect}")
    assert_response :redirect
    assert_redirected_to(:controller=> 'entries', :action => 'new')
    assert_equal num_journals + 1, Journal.count
  end

  def test_create_valid_redirect_to_show
    login_as "anauthor"
    num_journals = Journal.count
    start_date = 10.days.from_now
    end_date = 20.days.from_now
    post :create, :journal => {:title=> "test journal",
                               :scope=> User::SCOPE_PUBLIC,
                               :description=> "to introduce the test journal",
                               :start_date=> start_date.to_s,
                               :end_date=> end_date.to_s},
                  :user_id=> 1
    # puts("response: " + @response.body())
    assert_response :redirect
    assert_redirected_to(:action => 'show')
    assert_equal num_journals + 1, Journal.count
  end

  def test_create_invalid_WCJ_CJP_F05
    login_as "anauthor"
    num_journals = Journal.count
    start_date = 10.days.from_now
    end_date = 2.days.from_now
    post :create, :journal => {:title=> "test journal",
                               :scope=> User::SCOPE_PUBLIC,
                               :description=> "to introduce the test journal",
                               :start_date=> start_date.to_s,
                               :end_date=> end_date.to_s},
                  :user_id=> 1
    # puts("response: " + @response.body())
    assert_response :success
    assert_template 'journals/new'
    assert_equal num_journals, Journal.count
  end

  

  def test_destroy_as_admin
    login_as "anadmin"
    assert_not_nil Journal.find(1)
    post :destroy, :user_id=>1, :journal_id => 1
    assert_response :redirect
    assert_redirected_to(:controller=> 'users', :action => 'show')
    assert( journal = Journal.find(1))
    assert( journal.removed? )
  end

  # authors are now permitted to destroy their journals
  def test_destroy_as_author
    login_as "anauthor"
    assert_not_nil Journal.find(1)
    post :destroy, :user_id=>1, :journal_id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show'
    assert( journal = Journal.find(1))
    assert( journal.removed? )
  end

  # readers are not
  def test_destroy_as_reader
    login_as "reader1"
    assert_not_nil(journal = Journal.find(1))
    post :destroy, :user_id=>1, :journal_id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show'
    assert_not_nil(journal_after = Journal.find(1))
    assert_equal(journal.state, journal_after.state)
  end

  def test_edit
    login_as "anauthor"
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:journal)
    assert assigns(:journal).valid?
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list
    assert_response :success
    assert_template 'list'
    @controller.journals()
    assert(@controller.instance_variable_get(:@journals ).kind_of?(Array))
  end

  def test_new_with_id
    login_as "anauthor"
    get :new, :user_id=> 1
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:journal)
  end

  # should be not found
  def test_new_without_id
    login_as "anauthor"
    get :new
    assert_response(404)
  end

  def test_rss_WCJ_JP_F05
    get :rss
    assert_response :success
    assert_template("journals/journal_rss")
    assert_not_nil(journals = assigns(:journals))
    assert(journals.length > 0)
    assert(journals.any?{|i| i.scope == User::SCOPE_PRIVATE} == false)
  end
  
  def test_rss_entry_WCJ_JP_F05
    get :rss, :user_id=> 1, :journal_id=> 1
    assert_response :success
    assert_template("journals/entry_rss")
    assert_not_nil(user = assigns(:user))
    assert_not_nil(journal = assigns(:journal))
  end
  
  def test_show
    get :show, :user_id=> 1, :journal_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil(journal = assigns(:journal))
    assert( journal.valid? )
    assert(groups = assigns(:groups))
    assert_equal(journal.groups, groups)
    assert_equal(Journal.find(1).groups, groups)
  end

  def test_title
    get :show, :user_id => 1, :journal_id => 1
    assert_response :success
    assert_tag(:tag => "title", :parent => { :tag => "head" },
               :content=> Regexp.new("'#{Journal.find(1).title}' by #{User.find(1).login} - #{Settings.page_title}"))
  end
  
  def test_update
    login_as "anauthor"
    post :update, :user_id => 1, :journal_id=> 1
    assert_response :redirect
    assert_redirected_to :action => 'show', :journal_id => 1
  end

  def test_update_groups
    login_as "anauthor"
    journal = Journal.find(1)
    post :update, :user_id => 1, :journal_id=> 1,
         :journal=> {:group_ids=>[2]}
    journal = Journal.find(1)
    assert_response :redirect
    assert_redirected_to :action => 'show', :journal_id => 1
  end

  # enforce date currrency, now with a single date field
  def test_update_WCJ_EJP_F03
    login_as "anauthor"
    date = 1.day.ago
    post :update, :user_id => 1, :journal_id=> 1,
         :journal=> { :end_date=>date.to_s}
    # puts("test_add_and_remove flash: #{flash.inspect}")
    assert_response :success, :action=>'edit'
  end
  
  def test_add_and_remove
    login_as "anauthor"
    @request.env['HTTP_REFERER'] = Journal.find(1).url_hash()
    post :add, :user_id => 1, :journal_id=> 1, :group_id=>2
    assert_response :redirect
    assert_redirected_to(Journal.find(1).url_hash())
    group = Group.find(2)
    journal = Journal.find(1)
    # puts("test_add_and_remove flash: #{flash.inspect}")
    assert_not_nil(group.journals().index(journal))
    post :remove, :user_id => 1, :journal_id=> 1, :group_id=>2
    assert_response :redirect
    assert_redirected_to(Journal.find(1).url_hash())
    group = Group.find(2)
    assert(group.journals().include?(journal) == false)
  end

  # remove the group's owner from the members and the add should fail
  def test_add_and_remove_as_owner_only
    login_as "anauthor"
    @request.env['HTTP_REFERER'] = Journal.find(1).url_hash()
    group = Group.find(2)
    user = User.find(1)
    group.users.delete(user)
    group.save!()
    post :add, :user_id => 1, :journal_id=> 1, :group_id=>2
    assert_response :redirect
    assert_redirected_to(Journal.find(1).url_hash())
    group = Group.find(2)
    journal = Journal.find(1)
    # puts("test_add_and_remove flash: #{flash.inspect}")
    assert(group.journals().include?(journal) == false)
  end

  def test_add_and_remove_as_member_WCJ_AEG_N04
    login_as "reader1"
    group = Group.find(2)
    user = User.find(3)
    group.users << user
    group.save!()
    # puts("user: #{user}")
    # puts("members: #{group.users}")
    group.journals.delete(Journal.find(3))
    @request.env['HTTP_REFERER'] = Journal.find(3).url_hash()
    post :add, :user_id => 3, :journal_id=> 3, :group_id=>2
    assert_response :redirect
    assert_redirected_to(Journal.find(3).url_hash())
    # puts("flash: #{flash.inspect}")
    assert flash[:notice] =~ /.*Journal was successfully franchised.*/
    journal = Journal.find(3)
    assert_not_nil(group.journals().index(journal))
    @request.env['HTTP_REFERER'] = Journal.find(3).url_hash()
    post :remove, :user_id => 3, :journal_id=> 3, :group_id=>2
    assert_response :redirect
    assert_redirected_to(Journal.find(3).url_hash())
    group = Group.find(2)
    assert(group.journals().include?(journal) == false)
  end

end
