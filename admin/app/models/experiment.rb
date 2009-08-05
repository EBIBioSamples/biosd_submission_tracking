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

  belongs_to :user

  validates_numericality_of :miamexpress_subid, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_numericality_of :checker_score, :allow_nil => true, :only_integer => true, :message => "is not an integer"
  validates_inclusion_of :is_affymetrix,
                         :in_curation,
                           :allow_nil => true,
                           :in        => 0..1,
                           :message   => "is not 0 or 1"
  validates_inclusion_of :experiment_type,
                           :in      => %w(Tab2MAGE MIAMExpress MUGEN GEO MAGE-TAB Unknown),
                           :message => "is not recognized"
  validates_format_of :accession, :with => /^(E-[A-Z]{4}-\d+|unknown)?$/, :message => "is not the correct format"

  # Allow nulls but no other duplicated values
  validates_uniqueness_of :accession, :if => Proc.new{ |expt| expt.accession !~ /^(unknown)?$/ }

  validates_associated :organisms

  # Annotation mixin
  include Annotation
  
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
end
