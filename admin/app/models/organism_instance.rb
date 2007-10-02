class OrganismInstance < ActiveRecord::Base
  belongs_to :organism
  belongs_to :experiment
end
