class QuantitationTypeController < ApplicationController
  model :quantitation_type
  layout "admin"
  before_filter :login_required
end
