require File.dirname(__FILE__) + '/../test_helper'
require 'populate_controller'

# Re-raise errors caught by the controller.
class PopulateController; def rescue_action(e) raise e end; end

class PopulateControllerTest < Test::Unit::TestCase
  def setup
    @controller = PopulateController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
