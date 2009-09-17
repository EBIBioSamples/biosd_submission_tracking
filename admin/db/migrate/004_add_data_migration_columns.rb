class AddDataMigrationColumns < ActiveRecord::Migration
  def self.up
    add_column :experiments, :migration_status, :string
    add_column :experiments, :migration_comment, :text
    add_column :array_designs, :migration_status, :string
    add_column :array_designs, :migration_comment, :text
  end

  def self.down
    remove_column :experiments, :migration_status
    remove_column :experiments, :migration_comment
    remove_column :array_designs, :migration_status
    remove_column :array_designs, :migration_comment
  end
end
