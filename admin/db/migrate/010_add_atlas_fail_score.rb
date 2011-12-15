class AddAtlasFailScore < ActiveRecord::Migration
  def self.up
    add_column    :experiments, :atlas_fail_score, :string
    remove_column :experiments, :ae_data_warehouse_score
  end

  def self.down
    remove_column :experiments, :atlas_fail_score
    add_column    :experiments, :ae_data_warehouse_score, :int
  end
end
