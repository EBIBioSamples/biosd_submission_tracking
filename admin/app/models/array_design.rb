class ArrayDesign < ActiveRecord::Base

  has_and_belongs_to_many :organisms
  has_and_belongs_to_many :experiments
  has_many :events

  validates_presence_of :miamexpress_subid
  validates_uniqueness_of :miamexpress_subid

  validates_format_of :accession, :with => /^(A-[A-Z]{4}-\d+|unknown)?$/, :message => "is not the correct format"

  # Allow nulls but no other duplicated values
  validates_uniqueness_of :accession, :if => Proc.new{ |array| array.accession !~ /^(unknown)?$/ }

end
