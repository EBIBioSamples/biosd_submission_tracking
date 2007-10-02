class Design < ActiveRecord::Base
  has_and_belongs_to_many :categories
  has_many :design_instances
  has_many :experiments, :through => :design_instances
  validates_presence_of :display_label, :ontology_category, :ontology_value
  validates_uniqueness_of :display_label
end
