class AddSampleTable < ActiveRecord::Migration
  def self.up
    create_table :samples, :id=>true do |t|
      t.string   :accession
      t.string   :user_accession
      t.string   :submission_accession
      t.datetime :date_assigned
      t.datetime :date_last_processed
      t.text     :comment
      t.integer  :is_deleted
    end
  end

  def self.down
    drop_table :samples
  end
end
