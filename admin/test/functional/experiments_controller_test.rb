require File.dirname(__FILE__) + '/../test_helper'
require 'experiments_controller'

# Re-raise errors caught by the controller.
class ExperimentsController; def rescue_action(e) raise e end; end

class ExperimentsControllerTest < Test::Unit::TestCase
  fixtures :experiments
  fixtures :permissions, :roles, :users, :roles_users, :permissions_roles

  def setup
    @controller = ExperimentsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.session["user"] = @bob
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

    assert_not_nil assigns(:experiments)
  end

  def test_show
    get :show, :id => 1

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:experiment)
    assert assigns(:experiment).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:experiment)
  end

  def test_create
    num_experiments = Experiment.count

    post :create, :experiment => {:id => 4, :accession => 'E-GEOD-1',
                                  :experiment_type => 'GEO',
                                  :is_affymetrix => 0,
                                  :in_curation => 0}

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal num_experiments + 1, Experiment.count
  end

  def test_edit
    get :edit, :id => 1

    # Experiments are redirected to their tab2mage or miamexp
    # subclass. FIXME we should really add tests for these subclasses
    # at some point.
    assert_response :redirect
    assert_redirected_to :controller => 'tab2mages', :action => 'edit'

    assert_not_nil assigns(:experiment)
    assert assigns(:experiment).valid?
  end

  def test_update
    post :update, :id => 2
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_deprecate
    assert_not_nil Experiment.find(1)

    post :deprecate, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal(1, Experiment.find(1).is_deleted)
  end
end
