class Event < ActiveRecord::Base

  belongs_to :experiment
  belongs_to :array_design

  validates_presence_of :event_type

end
