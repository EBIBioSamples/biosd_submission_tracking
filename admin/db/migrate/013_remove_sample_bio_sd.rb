class RemoveSampleBioSd < ActiveRecord::Migration
  def self.up
  
  remove_column :experiments,   :is_uhts
  remove_column :experiments,   :use_native_datafiles
  remove_column :experiments,   :has_gds
  drop_table    :sample_assay
  drop_table     :sample_reference
  end

  def self.down
  add_column :experiments,      :is_uhts,       :integer
  add_column :experiments,      :use_native_datafiles,  :integer
  add_column :experiments,      :has_gds,       :integer
  end
end
