class EventController < ApplicationController
  model :event
  layout "admin"
  before_filter :login_required
end
