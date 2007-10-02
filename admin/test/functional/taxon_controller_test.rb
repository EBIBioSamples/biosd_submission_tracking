require File.dirname(__FILE__) + '/../test_helper'
require 'taxon_controller'

# Re-raise errors caught by the controller.
class TaxonController; def rescue_action(e) raise e end; end

class TaxonControllerTest < Test::Unit::TestCase
  def setup
    @controller = TaxonController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
