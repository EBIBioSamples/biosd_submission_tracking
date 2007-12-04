class Factor < ActiveRecord::Base

  has_and_belongs_to_many :experiments

  validates_presence_of :name

end
