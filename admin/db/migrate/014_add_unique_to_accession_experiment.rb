class AddUniqueToAccessionExperiment < ActiveRecord::Migration
  def self.up
        add_index :experiments, :accession, :unique => true
  end

  def self.down
        remove_index :experiments, :accession
  end
end
