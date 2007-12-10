class EventController < ApplicationController
  model :event
  layout "admin"
  before_filter :login_required

  def edit
    @event  = Event.find(params[:id])
  end

  def update
    @event = Event.find(params[:id])
    if @event.update_attributes(@params[:event])
      flash[:notice] = 'Event was successfully updated.'
      redirect_to :action => 'edit',
		  :id     => @event.id
    else
      render :action => 'edit'
    end
  end

end
