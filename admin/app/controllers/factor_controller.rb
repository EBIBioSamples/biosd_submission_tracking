class FactorController < ApplicationController
  model :factor
  layout "admin"
  before_filter :login_required
end
