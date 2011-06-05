require File.dirname(__FILE__) + '/../test_helper'
require 'account_controller'
require "application_helper" # needed for is_home?() in the layout/pblic

# Re-raise errors caught by the controller.
class AccountController; def rescue_action(e) raise e end; end

class AccountControllerTest < Test::Unit::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead
  # Then, you can remove it from this and the units test.
  # include AuthenticatedTestHelper

  fixtures :users, :roles, :roles_users

  def setup
    @controller = AccountController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # login success redirects to the user's home page
  def test_should_login_and_redirect
    post :login, :login => 'anauthor', :password => 'test'
    assert session[:user]
    # assert_response :redirect
    assert_redirected_to :controller=> 'users', :action=> 'show',
                         :user_id=> session[:user]
  end

  def test_should_fail_login_and_not_redirect
    post :login, :login => 'anauthor', :password => 'bad password'
    assert_nil session[:user]
    assert_response :success
  end

  def test_should_allow_signup
    assert_difference User, :count do
      create_user
      assert_response :redirect
    end
  end

  # signup success redirects to the user's home page
  def test_WCJ_ASU_N02
    post :signup, :user=> {:first_name=> 'test', :last_name=> 'user',
                           :login=> 'testuser',
                           :email=> 'testuser@example.net',
                           :password=> 'apassword', :password_confirmation=> 'apassword',
                           :state=> "pending",
                           :scope=> User::SCOPE_PUBLIC,
                           :description=> "this is a test user"}
    
    assert session[:user]
    assert_redirected_to :controller=> 'users', :action=> 'show',
                         :user_id=> session[:user]
  end

  # require a unique login
  def test_WCJ_ASU_F01
    post :signup, :user=> {:first_name=> 'test', :last_name=> 'user',
                           :login=> 'anauthor',
                           :email=> 'testuser@example.net',
                           :password=> 'apassword', :password_confirmation=> 'apassword',
                           :state=> "pending",
                           :scope=> User::SCOPE_PUBLIC,
                           :description=> "this is a test user"}
    assert_response :success, :layout=> 'signup'
  end
  
  def test_should_require_login_on_signup
    assert_no_difference User, :count do
      create_user(:login => nil)
      assert assigns(:user).errors.on(:login)
      assert_response :success
    end
  end

  # require password and comfirmation on signup
  # failure repeats the signup page
  def test_WCJ_ASU_F03a
    assert_no_difference User, :count do
      create_user(:password => nil)
      assert assigns(:user).errors.on(:password)
      assert_response :success, :layout=> 'signup'
    end
  end

  # require password and comfirmation on signup
  def test_WCJ_ASU_F03b
    assert_no_difference User, :count do
      create_user(:password_confirmation => nil)
      assert assigns(:user).errors.on(:password_confirmation)
      assert_response :success, :layout=> 'signup'
    end
  end

  def test_should_require_email_on_signup
    assert_no_difference User, :count do
      create_user(:email => nil)
      assert assigns(:user).errors.on(:email)
      assert_response :success
    end
  end

  def test_should_logout
    login_as :anauthor
    assert_not_nil @request.session[:user]
    get :logout
    assert_nil session[:user]
    assert_response :redirect
  end

  def test_should_remember_me
    post :login, :login => 'anauthor', :password => 'test', :remember_me => "1"
    # puts("test_should_remember_me: " + @response.cookies.inspect())
    # puts("["+cookies["auth_token"].to_s() + "==" + cookies[:auth_token].to_s()+"]")
    assert_not_nil @response.cookies["auth_token"]
  end

  def test_should_not_remember_me
    post :login, :login => 'anauthor', :password => 'test', :remember_me => "0"
    assert_nil @response.cookies[:auth_token]
  end
  
  def test_should_delete_token_on_logout
    login_as :anauthor
    get :logout
    assert_nil @response.cookies[:auth_token], []
  end

  def test_should_login_with_cookie
    users(:anauthor).remember_me
    @request.cookies["auth_token"] = cookie_for(:anauthor)
    get :login
    assert @controller.send(:logged_in?)
  end

  def test_should_fail_cookie_login
    users(:anauthor).remember_me
    users(:anauthor).update_attribute :remember_token_expires_at, 5.minutes.ago.utc
    @request.cookies["auth_token"] = cookie_for(:anauthor)
    get :login
    assert !@controller.send(:logged_in?)
  end

  def test_should_fail_cookie_login
    users(:anauthor).remember_me
    @request.cookies["auth_token"] = auth_token('invalid_auth_token')
    get :login
    assert !@controller.send(:logged_in?)
  end

  def test_invalid_utc_offset
    post :signup, :user=> {:first_name=> 'test', :last_name=> 'user',
                           :login=> 'testuser',
                           :email=> 'testuser@example.net',
                           :password=> 'apassword', :password_confirmation=> 'apassword',
                           :state=> "pending",
                           :scope=> User::SCOPE_PUBLIC,
                           :description=> "this is a test user"},
                  :utc_offset=>'<xyz'
    assert_response :success, :layout=> 'signup'
  end
  
  protected
    def create_user(options = {})
      post :signup, :user => { :login => 'quire', :email => 'quire@example.com', 
        :password => 'quire', :password_confirmation => 'quire' }.merge(options)
    end
    
    def auth_token(token)
      CGI::Cookie.new('name' => 'auth_token', 'value' => token)
    end
    
    def cookie_for(user)
      auth_token users(user).remember_token
    end
end
