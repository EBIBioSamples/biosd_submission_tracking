require File.dirname(__FILE__) + '/../test_helper'
require 'array_designs_controller'

# Re-raise errors caught by the controller.
class ArrayDesignsController; def rescue_action(e) raise e end; end

class ArrayDesignsControllerTest < Test::Unit::TestCase
  fixtures :array_designs

  def setup
    @controller = ArrayDesignsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
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

    assert_not_nil assigns(:array_designs)
  end

  def test_show
    get :show, :id => 1

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:array_design)
    assert assigns(:array_design).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:array_design)
  end

  def test_create
    num_array_designs = ArrayDesign.count

    post :create, :array_design => {:id => 3, :subid => 3, :accession => 3}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_array_designs + 1, ArrayDesign.count
  end

  def test_edit
    get :edit, :id => 1

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:array_design)
    assert assigns(:array_design).valid?
  end

  def test_update
    post :update, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_destroy
    assert_not_nil ArrayDesign.find(1)

    post :delete, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      ArrayDesign.find(1)
    }
  end
end
