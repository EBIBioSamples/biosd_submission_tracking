class RemoveColsForBioSd < ActiveRecord::Migration
  def self.up
    remove_column :experiments,   :name
    remove_column :experiments,   :user_id
    remove_column :experiments,   :checker_score
    remove_column :experiments,   :software
    remove_column :experiments,   :data_warehouse_ready
    remove_column :experiments,   :date_last_edited
    remove_column :experiments,   :in_curation
    remove_column :experiments,   :curator
    remove_column :experiments,   :experiment_type
    remove_column :experiments,   :miamexpress_login
    remove_column :experiments,   :miamexpress_subid
    remove_column :experiments,   :is_affymetrix
    remove_column :experiments,   :is_mx_batchloader
    remove_column :experiments,   :miame_score
    remove_column :experiments,   :in_data_warehouse
    remove_column :experiments,   :submitter_description
    remove_column :experiments,   :curated_name
    remove_column :experiments,   :num_hybridizations
    remove_column :experiments,   :has_raw_data
    remove_column :experiments,   :has_processed_data
    remove_column :experiments,   :ae_miame_score
    remove_column :experiments,   :ae_data_warehouse_score
  end

  def self.down
    add_column :experiments,   :name
    add_column :experiments,   :user_id
    add_column :experiments,   :checker_score
    add_column :experiments,   :software
    add_column :experiments,   :data_warehouse_ready
    add_column :experiments,   :date_last_edited
    add_column :experiments,   :in_curation
    add_column :experiments,   :curator
    add_column :experiments,   :experiment_type
    add_column :experiments,   :miamexpress_login
    add_column :experiments,   :miamexpress_subid
    add_column :experiments,   :is_affymetrix
    add_column :experiments,   :is_mx_batchloader
    add_column :experiments,   :miame_score
    add_column :experiments,   :in_data_warehouse
    add_column :experiments,   :submitter_description
    add_column :experiments,   :curated_name
    add_column :experiments,   :num_hybridizations
    add_column :experiments,   :has_raw_data
    add_column :experiments,   :has_processed_data
    add_column :experiments,   :ae_miame_score
    add_column :experiments,   :ae_data_warehouse_score
    
  end
end
