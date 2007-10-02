require File.dirname(__FILE__) + '/../test_helper'
require 'miamexps_controller'

# Re-raise errors caught by the controller.
class MiamexpsController; def rescue_action(e) raise e end; end

class MiamexpsControllerTest < Test::Unit::TestCase
  def setup
    @controller = MiamexpsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
