require File.dirname(__FILE__) + '/../test_helper'
require 'pages_controller'

# Re-raise errors caught by the controller.
class PagesController; def rescue_action(e) raise e end; end

class PagesControllerTest < Test::Unit::TestCase
  fixtures :users

  def setup
    @controller = PagesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_privacy_guest
    get :privacy
    assert_response :success
    assert_template 'privacy'
  end

  def test_privacy_author
    login_as "anauthor"
    get :privacy
    assert_response :success
    assert_template 'privacy'
  end

end
