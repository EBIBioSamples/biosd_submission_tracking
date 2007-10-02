class Material < ActiveRecord::Base
  has_and_belongs_to_many :categories
  has_many :material_instances
  has_many :experiments, :through => :material_instances
  validates_presence_of :display_label, :ontology_category, :ontology_value
  validates_uniqueness_of :display_label
end
