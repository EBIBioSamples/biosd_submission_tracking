class Taxon < ActiveRecord::Base
  has_many :organisms
  has_and_belongs_to_many :categories
  validates_presence_of :accession, :common_name, :scientific_name
  validates_uniqueness_of :accession, :common_name, :scientific_name
  validates_numericality_of :accession, :only_integer => true, :message => "is not an integer"
  validates_associated :categories
end
