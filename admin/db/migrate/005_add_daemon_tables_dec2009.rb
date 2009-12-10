class AddDaemonTablesDec2009 < ActiveRecord::Migration
  def self.up
    create_table :pipelines do |t|
      t.string  :submission_type, :null => false
      t.integer :instances_to_start, :default => 1
      t.string  :checker_daemon
      t.string  :exporter_daemon
      t.integer :polling_interval, :default => 5
      t.string  :checker_threshold, :default => "ERROR_INNOCENT, ERROR_MIAME"
      t.string  :qt_filename
      t.boolean :keep_protocol_accns, :default => 0
      t.string  :accession_prefix
      t.string  :pipeline_subdir
    end
    
    Pipeline.create :submission_type => "Tab2MAGE", 
                    :checker_daemon => "T2MChecker", 
                    :exporter_daemon => "T2MExporter", 
                    :accession_prefix => "E-TABM-",
                    :pipeline_subdir => "TABM"
              
    Pipeline.create :submission_type => "MAGE-TAB", 
                    :checker_daemon => "MAGETABChecker", 
                    :exporter_daemon => "MAGETABExporter", 
                    :accession_prefix => "E-MTAB-",
                    :pipeline_subdir => "MTAB"
                    
    Pipeline.create :submission_type => "GEO", 
                    :checker_daemon => "MAGETABChecker", 
                    :exporter_daemon => "MAGETABExporter",
                    :checker_threshold => "ERROR_INNOCENT,ERROR_PARSEBAD,ERROR_MIAME,ERROR_ARRAYEXPRESS",
                    :keep_protocol_accns => 1,
                    :pipeline_subdir => "GEOD"
    
    Pipeline.create :submission_type => "MIAMExpress", 
                    :checker_daemon => "MXChecker",  
                    :accession_prefix => "E-MEXP-"
                    
    Pipeline.create :submission_type => "BII",
                    :instances_to_start => 0,
                    :checker_daemon => "MAGETABChecker", 
                    :exporter_daemon => "MAGETABExporter", 
                    :accession_prefix => "E-BIID-",
                    :pipeline_subdir => "BIID"
                    
    create_table :daemon_instances do |t|
      t.integer :pipeline_id
      t.string  :daemon_type
      t.integer :pid
      t.time    :start_time
      t.time    :end_time
      t.boolean :running
      t.string  :user
    end
  end

  def self.down
    drop_table :pipelines
    drop_table :daemon_instances
  end
end
