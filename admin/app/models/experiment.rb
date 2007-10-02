require_dependency 'annotation'

class Experiment < ActiveRecord::Base
  has_many   :design_instances,   :dependent => :destroy
  has_many   :designs,            :through   => :design_instances

  has_many   :material_instances, :dependent => :destroy
  has_many   :materials,          :through   => :material_instances

  has_many   :organism_instances, :dependent => :destroy
  has_many   :organisms,          :through   => :organism_instances

  has_many   :spreadsheets
  has_many   :data_files

  belongs_to :user

  validates_numericality_of :miamexpress_subid, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_numericality_of :checker_score, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_inclusion_of :is_affymetrix,
                         :in_curation,
                           :allow_nil => true,
                           :in        => 0..1,
                           :message   => "is not 0 or 1"
  validates_inclusion_of :experiment_type,
                           :in      => %w(Tab2MAGE MIAMExpress MUGEN GEO MAGE-TAB),
                           :message => "is not recognized"
  validates_format_of :accession, :with => /^(E-[A-Z]{4}-\d+|unknown)?$/, :message => "is not the correct format"

  # Allow nulls but no other duplicated values
  validates_uniqueness_of :accession, :if => Proc.new{ |expt| expt.accession !~ /^(unknown)?$/ }

  # Annotation mixin
  include Annotation
end
