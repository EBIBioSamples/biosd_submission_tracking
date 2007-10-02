class MaterialInstance < ActiveRecord::Base
  belongs_to :material
  belongs_to :experiment
end
