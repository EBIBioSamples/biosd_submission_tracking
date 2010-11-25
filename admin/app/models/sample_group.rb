class SampleGroup < ActiveRecord::Base
  validates_presence_of :user_accession, :submission_accession
  validates_uniqueness_of :accession
end