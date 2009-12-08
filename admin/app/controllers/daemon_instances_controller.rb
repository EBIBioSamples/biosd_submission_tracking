class DaemonInstancesController < ApplicationController

  include AutosubsCommon

  layout "admin"
  before_filter :login_required
  
  def index
    list
    render :action => 'list'    
  end

  def list
    
    order_by = 'start_time DESC'
    
    params[:page] ||= 1
    @daemons = DaemonInstance.paginate :page => params[:page],
      :per_page   => 40,
      :order      => order_by    
  end
  
  def show
  end
end
