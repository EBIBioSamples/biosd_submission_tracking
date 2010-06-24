class ExperimentQualityMetric < ActiveRecord::Base
  belongs_to :experiment
  belongs_to :quality_metric
end