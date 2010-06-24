class QualityMetric < ActiveRecord::Base
  has_many :experiment_quality_metrics
end