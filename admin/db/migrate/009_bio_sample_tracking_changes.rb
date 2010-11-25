class BioSampleTrackingChanges < ActiveRecord::Migration
  def self.up
    add_column :samples,   :source_repository, :string
    
    create_table :sample_groups, :id=>true do |t|
      t.string   :accession
      t.string   :user_accession
      t.string   :submission_accession
      t.string   :project_name
      t.string   :source_repository
      t.string   :linking_repositories
      t.datetime :date_assigned
      t.datetime :date_last_processed
      t.text     :comment
      t.integer  :is_deleted
    end
    
  end

  def self.down
    remove_column :samples,   :source_repository
    drop_table    :sample_groups
  end
end
