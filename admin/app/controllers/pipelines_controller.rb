class PipelinesController < ApplicationController

  include AutosubsCommon

  layout "admin"
  before_filter :login_required
  
  def index
    list
    render :action => 'list'
  end

  def list
    order_by = 'submission_type ASC'
    
    params[:page] ||= 1
    @pipelines = Pipeline.paginate :page => params[:page],
      :per_page   => 40,
      :order      => order_by    
  end

  def new
  end

  def edit
  end

  def show
  end
end
