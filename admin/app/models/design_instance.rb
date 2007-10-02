class DesignInstance < ActiveRecord::Base
  belongs_to :design
  belongs_to :experiment
end
