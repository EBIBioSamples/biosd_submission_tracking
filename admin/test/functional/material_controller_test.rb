require File.dirname(__FILE__) + '/../test_helper'
require 'material_controller'

# Re-raise errors caught by the controller.
class MaterialController; def rescue_action(e) raise e end; end

class MaterialControllerTest < Test::Unit::TestCase

  fixtures :materials

  def setup
    @controller = MaterialController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
