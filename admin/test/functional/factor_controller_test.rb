require File.dirname(__FILE__) + '/../test_helper'
require 'factor_controller'

# Re-raise errors caught by the controller.
class FactorController; def rescue_action(e) raise e end; end

class FactorControllerTest < Test::Unit::TestCase

  fixtures :factors

  def setup
    @controller = FactorController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
