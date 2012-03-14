require_dependency 'annotation'

class Experiment < ActiveRecord::Base
 
  has_many   :design_instances,   :dependent => :destroy
  has_many   :designs,            :through   => :design_instances

  has_many   :material_instances, :dependent => :destroy
  has_many   :materials,          :through   => :material_instances

  has_many   :organism_instances, :dependent => :destroy
  has_many   :organisms,          :through   => :organism_instances

  has_and_belongs_to_many :factors
  has_and_belongs_to_many :quantitation_types
  has_and_belongs_to_many :array_designs

  has_many   :spreadsheets
  has_many   :data_files

  has_many   :events
  has_many   :experiment_quality_metrics

  belongs_to :user

  validates_numericality_of :miamexpress_subid, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_numericality_of :checker_score, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_inclusion_of :is_affymetrix,
                         :in_curation,
                           :allow_nil => true,
                           :in        => 0..1,
                           :message   => "is not 0 or 1"
  
 
  #Old list of expt types: %w(Tab2MAGE MIAMExpress MUGEN GEO MAGE-TAB ESD BII Unknown)
  validates_inclusion_of :experiment_type,
                           :in      => Pipeline.find(:all).map{ |p| p.submission_type },
                           :message => "is not recognized"
  validates_format_of :accession, :with => /^(E-[A-Z]{4}-\d+|unknown)?$/, :message => "is not the correct format"

  # Allow nulls but no other duplicated values
  validates_uniqueness_of :accession, :if => Proc.new{ |expt| expt.accession !~ /^(unknown)?$/ }

  validates_associated :organisms
  
  validates_numericality_of :in_curation, :equal_to => 1, :if => "status == \"Abandoned\"", :message => ": Abandoned experiments must be put in curation to prevent user access"

  # Annotation mixin
  include Annotation
  
  def self.migration_status_list
    # get count of each non-null values for migration_status
    return self.count(:group => "migration_status", :conditions => "migration_status is not null")
  end
  
  def directory
    dir = ''
    if self.experiment_type == 'MIAMExpress' 
      dir = self.miamexpress_login + "/submission" + self.miamexpress_subid.to_s
    else
      dir = self.experiment_type + '_' + self.id.to_s
    end
    return dir
  end
  
  def miame_score_html
    score = (self.miame_score.to_i.&(1).nonzero? ? 'R' : '') +
            (self.miame_score.to_i.&(2).nonzero? ? 'N' : '') +
            (self.miame_score.to_i.&(4).nonzero? ? 'F' : '') +
            (self.miame_score.to_i.&(8).nonzero? ? 'P' : '') +
            (self.miame_score.to_i.&(16).nonzero? ? 'A' : '')
    return score        
  end
  
  def dw_status_html
    status = self.in_data_warehouse?                 ? '<font color="blue">Loaded</font>'  :
             self.data_warehouse_ready.nil?          ? '' :
             self.data_warehouse_ready.to_i.eql?(31) ? '<font color="green">YES</font>' :
             self.data_warehouse_ready.to_i.eql?(30) ? '<font color="red">maybe</font>' :
             '<font color="red">no</font>'
    return status         
  end
  
  def atlas_status_html
    status = self.in_data_warehouse?                 ? '<font color="blue">Loaded</font>'  :
             self.atlas_fail_score.nil?              ? '' :
             '<font color="red">'+self.atlas_fail_score+'</font>'
    return status         
  end 

  def ae_data_warehouse_score
    return self.atlas_fail_score
  end 
end
