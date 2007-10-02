class Protocol < ActiveRecord::Base
  validates_presence_of :user_accession, :expt_accession
  validates_uniqueness_of :accession
end
