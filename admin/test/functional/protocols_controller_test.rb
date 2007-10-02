require File.dirname(__FILE__) + '/../test_helper'
require 'protocols_controller'

# Re-raise errors caught by the controller.
class ProtocolsController; def rescue_action(e) raise e end; end

class ProtocolsControllerTest < Test::Unit::TestCase
  fixtures :protocols

  def setup
    @controller = ProtocolsController.new
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

    assert_not_nil assigns(:protocols)
  end

  def test_show
    get :show, :id => 1

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:protocol)
    assert assigns(:protocol).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:protocol)
  end

  def test_create
    num_protocols = Protocol.count

    post :create, :protocol => {:id => 3, :accession => 3, :user_accession => 3, :expt_accession => 3}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_protocols + 1, Protocol.count
  end

  def test_edit
    get :edit, :id => 1

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:protocol)
    assert assigns(:protocol).valid?
  end

  def test_update
    post :update, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_destroy
    assert_not_nil Protocol.find(1)

    post :delete, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      Protocol.find(1)
    }
  end
end
