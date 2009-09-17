class AddIsUhtsFlagToExperimentsRev2227May2009 < ActiveRecord::Migration
  def self.up
    begin
      add_column :experiments, :is_uhts, :integer
    rescue
      puts "Did not add column is_uhts to experiments"
    end
  end

  def self.down
    remove_column :experiments, :is_uhts
  end
end
