class ArrayDesign < ActiveRecord::Base

  has_and_belongs_to_many :organisms
  has_and_belongs_to_many :experiments
  has_many :events

  validates_format_of :accession, :with => /^(A-[A-Z]{4}-\d+|unknown)?$/, :message => "is not the correct format"

  # Allow nulls but no other duplicated values
  validates_uniqueness_of :accession, :if => Proc.new{ |array| array.accession !~ /^(unknown)?$/ }

  def miame_score_html
    return '' if self.miame_score.nil?
    return '<font color="gray">unknown</font>' if self.miame_score == -1
    if self.miame_score > 0
      return '<font color="green">PASS</font>'
    else
      return '<font color="red">fail</font>'
    end 
  end
  
  def dw_status_html
    return '<font color="blue">Loaded</font>' if self.in_data_warehouse.to_i > 0
  	return '' if self.data_warehouse_ready.nil?
    return '<font color="gray">unknown</font>' if self.data_warehouse_ready.to_i == -1
    if self.data_warehouse_ready.to_i > 0
      return '<font color="green">YES</font>'
    else
      return '<font color="red">no</font>'
    end
  end

  def experiment_type
    return 'ArrayDesign'
  end
  
  def checker_score
    return ''
  end

  def curator
    return ''
  end
  
  def directory
    if self.miamexpress_login and self.miamexpress_subid
      return self.miamexpress_login + "/array" + self.miamexpress_subid.to_s 
    end
    return ''
  end
end
