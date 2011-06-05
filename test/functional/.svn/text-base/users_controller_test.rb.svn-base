#!ruby
#
# c 2006 makalumedia
# 
# Journal class functional tests
# 
# 2006-11-20  james.anderson
# 2006-11-29  james.anderson  #53, #54

require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @controller = UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_create
    login_as "anauthor"
    num_users = User.count
    post :create, :user => { :login=> "testuser",
                             :first_name=>"test", :last_name=> "user",
                             :email=> "testuser@example.com",
                             :password=> "testme",
                             :password_confirmation=> "testme",
                             :created_at=> Time.now.utc(),
                             :state=> :active,
                             :scope=> User::SCOPE_PUBLIC,
                             :description=> "this is an adminstrator"
                             }
    # puts("test_create: flash: #{flash.inspect}")
    assert assigns(:user).time_zone() == "UTC"
    assert_response :redirect
    assert_redirected_to :action => 'list'
    assert_equal num_users + 1, User.count
  end
  
  def test_create_with_zone
    login_as "anauthor"
    num_users = User.count
    post :create, :user => { :login=> "testuser",
                             :first_name=>"test", :last_name=> "user",
                             :email=> "testuser@example.com",
                             :password=> "testme",
                             :password_confirmation=> "testme",
                             :created_at=> Time.now.utc(),
                             :state=> :active,
                             :scope=> User::SCOPE_PUBLIC,
                             :description=> "this is an adminstrator",
                             :time_zone=>"America/New_York"
                             }
    # puts("test_create: flash: #{flash.inspect}")
    # puts("zone: #{assigns(:user).time_zone()}")
    assert assigns(:user).time_zone() == "America/New_York"
    assert_response :redirect
    assert_redirected_to :action => 'list'
    assert_equal num_users + 1, User.count
  end

  def test_destroy_as_admin
    login_as "anadmin"
    assert_not_nil User.find(1)
    post :destroy, :user_id => 1
    assert_response :redirect
    assert_redirected_to(home_url)
    assert((user = User.find(1)) && user.removed?)
  end

  def test_destroy_as_guest
    assert_not_nil User.find(1)
    post :destroy, :user_id => 1
    assert_response 302 # redirects
    assert((user = User.find(1)) && user.active?)
  end
  
  def test_destroy_as_incorrect_user
    login_as "reader1"
    assert_not_nil User.find(1)
    post :destroy, :user_id => 1
    assert_response 302
    assert((user = User.find(1)) && user.active?)
  end
  
  def test_destroy_as_correct_user
    login_as "anauthor"
    assert_not_nil User.find(1)
    post :destroy, :user_id => 1
    assert_response :redirect
    assert_redirected_to(home_url)
    assert((user = User.find(1)) && user.removed?)
  end
  
  def test_edit
    login_as "anauthor"
    get :edit, :user_id => 1
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:user)
    assert assigns(:user).valid?
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
    @controller.users()
    assert(@controller.instance_variable_get(:@users).kind_of?(Array))
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:user)
  end
  
  def test_rss_WCJ_AHP_F07
    get :rss
    assert_response :success
    assert_not_nil(users = assigns(:users))
    assert(users.length > 0)
    assert(users.any?{|i| i.scope == User::SCOPE_PRIVATE} == false)
  end
  
  def test_show
    get :show, :user_id => 1
    assert_response :success
    assert_template 'show'
    assert_tag(:tag => "title", :parent => { :tag => "head" },
               :content=> Regexp.new("#{User.find(1).login} - #{Settings.page_title}"))
    assert_not_nil assigns(:user)
    assert assigns(:user).valid?
  end
  
  def test_title
    get :show, :user_id => 1
    assert_response :success
    assert_tag(:tag => "title", :parent => { :tag => "head" },
               :content=> Regexp.new("#{User.find(1).login} - #{Settings.page_title}"))
  end
  
  def test_update
    login_as "anauthor"
    post :update, :user_id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show', :user_id => 1
  end

  def test_add_favorite
    login_as "anauthor"
    @request.env["HTTP_REFERER"] = "http://wcj"
    post :add_favorite, "scope"=>"public", "journal_id"=>"1", "user_id"=>"1"
    assert_equal(User::SCOPE_PUBLIC,
                 User.find_by_login("anauthor").asserted(Journal.find(1), User::FAVORITE))
  end
end
