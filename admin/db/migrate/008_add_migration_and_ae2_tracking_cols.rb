class AddMigrationAndAe2TrackingCols < ActiveRecord::Migration
  def self.up
    add_column :experiments,   :migration_source, :string
    add_column :experiments,   :file_to_load,     :string
    add_column :array_designs, :file_to_load,     :string
  end

  def self.down
    remove_column :experiments,   :migration_source
    remove_column :experiments,   :file_to_load
    remove_column :array_designs, :file_to_load    
  end
end
