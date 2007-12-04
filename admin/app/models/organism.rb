class Organism < ActiveRecord::Base
  belongs_to :taxon
  has_many :organism_instances
  has_many :experiments, :through => :organism_instances
  has_and_belongs_to_many :array_designs
  validates_presence_of :accession, :common_name, :scientific_name, :taxon
  validates_uniqueness_of :accession, :common_name, :scientific_name
  validates_numericality_of :accession, :only_integer => true, :message => "is not an integer"
  validates_associated :taxon
end
