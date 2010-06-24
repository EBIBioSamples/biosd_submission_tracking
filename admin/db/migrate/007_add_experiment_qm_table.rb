class AddExperimentQmTable < ActiveRecord::Migration
  def self.up
    create_table :experiment_quality_metrics, :id=>true do |t|
      t.string   :value
      t.integer  :quality_metric_id
      t.integer  :experiment_id
      t.string   :status
      t.datetime :date_calculated
    end
    
    # Also change column name to avoid error
    # because the column 'type' is reserved for storing the class in case of inheritance
    rename_column :quality_metrics, :type, :name
    
  end

  def self.down
    drop_table :experiment_quality_metrics
  end
end
