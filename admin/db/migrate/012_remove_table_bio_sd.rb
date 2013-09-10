class RemoveTableBioSd < ActiveRecord::Migration
  def self.up
        drop_table  :array_designs
        drop_table  :array_designs_experiments
        drop_table  :array_designs_organisms
        drop_table  :categories
        drop_table  :categories_designs
        drop_table  :categories_materials
        drop_table  :categories_taxons
        drop_table  :design_instances
        drop_table  :designs
        drop_table  :experiment_quality_metrics
        drop_table  :experiments_factors
        drop_table  :experiments_quantitation_types
        drop_table  :factors
        drop_table  :data_files
        drop_table  :experiments_loaded_data
        drop_table  :loaded_data
        drop_table  :loaded_data_quality_metrics
        drop_table  :material_instances
        drop_table  :materials
        drop_table  :organism_instances
        drop_table  :organisms
        drop_table  :pipelines
        drop_table  :platforms
        drop_table  :protocols
        drop_table  :quality_metrics
        drop_table  :quantitation_types
        drop_table  :sample_groups
        drop_table  :samples
        drop_table  :taxons
        drop_table  :spreadsheets
        
  end

  def self.down
  end
end
