require File.dirname(__FILE__) + '/../test_helper'
require 'quantitation_type_controller'

# Re-raise errors caught by the controller.
class QuantitationTypeController; def rescue_action(e) raise e end; end

class QuantitationTypeControllerTest < Test::Unit::TestCase
  
  fixtures :quantitation_types

  def setup
    @controller = QuantitationTypeController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
