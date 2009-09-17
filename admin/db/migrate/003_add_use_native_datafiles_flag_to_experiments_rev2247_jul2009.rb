class AddUseNativeDatafilesFlagToExperimentsRev2247Jul2009 < ActiveRecord::Migration
  def self.up
    begin
      add_column :experiments, :use_native_datafiles, :integer
    rescue
      puts "Did not add column use_native_datafiles to experiments"
    end  
  end

  def self.down
    remove_column :experiments, :use_native_datafiles
  end
end
