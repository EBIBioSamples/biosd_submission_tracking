class Category < ActiveRecord::Base
  has_and_belongs_to_many :taxons
  has_and_belongs_to_many :designs
  has_and_belongs_to_many :materials
  validates_presence_of :ontology_term, :display_label
  validates_uniqueness_of :display_label
end
