require File.dirname(__FILE__) + '/../test_helper'
require 'array_designs_controller'

# Re-raise errors caught by the controller.
class ArrayDesignsController; def rescue_action(e) raise e end; end

class ArrayDesignsControllerTest < Test::Unit::TestCase
  fixtures :array_designs
  fixtures :permissions, :roles, :users, :roles_users, :permissions_roles

  def setup
    @controller = ArrayDesignsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.session[:user] = @bob
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

    post :create, :array_design => {:id => 3, :miamexpress_subid => 1003, :accession => "A-MEXP-3"}

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
    assert_redirected_to :action => 'list_all'
  end

  def test_deprecate
    assert_not_nil ArrayDesign.find(1)

    post :deprecate, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal(1, ArrayDesign.find(1).is_deleted)
  end
end
