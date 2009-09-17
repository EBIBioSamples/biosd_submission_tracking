class AddHasGdsFlagToExperimentsRev2137Nov2008 < ActiveRecord::Migration
  def self.up
    begin
      add_column :experiments, :has_gds, :boolean
    rescue
      puts "Did not add column has_gds to experiments"
    end
  end

  def self.down
    remove_column :experiments, :has_gds
  end
end
