# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 5) do

  create_table "array_designs", :force => true do |t|
    t.integer  "miamexpress_subid"
    t.string   "accession"
    t.string   "name"
    t.string   "miamexpress_login",    :limit => 50
    t.string   "status",               :limit => 50
    t.string   "data_warehouse_ready", :limit => 15
    t.datetime "date_last_processed"
    t.text     "comment"
    t.integer  "is_deleted",                         :null => false
    t.integer  "miame_score"
    t.integer  "in_data_warehouse"
    t.string   "annotation_source",    :limit => 50
    t.string   "annotation_version",   :limit => 50
    t.string   "biomart_table_name",   :limit => 50
    t.datetime "release_date"
    t.integer  "is_released"
    t.string   "migration_status"
    t.text     "migration_comment"
  end

  add_index "array_designs", ["miamexpress_subid"], :name => "miamexpress_subid", :unique => true

  create_table "array_designs_experiments", :force => true do |t|
    t.integer "array_design_id", :null => false
    t.integer "experiment_id",   :null => false
  end

  add_index "array_designs_experiments", ["array_design_id"], :name => "array_design_id"
  add_index "array_designs_experiments", ["experiment_id"], :name => "experiment_id"

  create_table "array_designs_organisms", :force => true do |t|
    t.integer "organism_id",     :null => false
    t.integer "array_design_id", :null => false
  end

  add_index "array_designs_organisms", ["organism_id"], :name => "organism_id"
  add_index "array_designs_organisms", ["array_design_id"], :name => "array_design_id"

  create_table "categories", :force => true do |t|
    t.string  "ontology_term", :limit => 50
    t.string  "display_label", :limit => 50
    t.integer "is_common"
    t.integer "is_bmc"
    t.integer "is_fv"
    t.integer "is_deleted",                  :null => false
  end

  create_table "categories_designs", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "design_id",   :null => false
  end

  add_index "categories_designs", ["category_id"], :name => "category_id"
  add_index "categories_designs", ["design_id"], :name => "design_id"

  create_table "categories_materials", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "material_id", :null => false
  end

  add_index "categories_materials", ["category_id"], :name => "category_id"
  add_index "categories_materials", ["material_id"], :name => "material_id"

  create_table "categories_taxons", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "taxon_id",    :null => false
  end

  add_index "categories_taxons", ["category_id"], :name => "category_id"
  add_index "categories_taxons", ["taxon_id"], :name => "taxon_id"

  create_table "daemon_instances", :force => true do |t|
    t.integer  "pipeline_id"
    t.string   "daemon_type"
    t.integer  "pid"
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean  "running"
    t.string   "user"
  end

  create_table "data_files", :force => true do |t|
    t.integer "experiment_id", :null => false
    t.string  "name"
    t.integer "is_unpacked"
    t.integer "is_deleted",    :null => false
  end

  add_index "data_files", ["experiment_id"], :name => "experiment_id"

  create_table "data_formats", :force => true do |t|
    t.string "name", :limit => 50, :default => "", :null => false
  end

  add_index "data_formats", ["name"], :name => "name", :unique => true

  create_table "design_instances", :force => true do |t|
    t.integer "design_id",     :null => false
    t.integer "experiment_id", :null => false
  end

  add_index "design_instances", ["design_id"], :name => "design_id"
  add_index "design_instances", ["experiment_id"], :name => "experiment_id"

  create_table "designs", :force => true do |t|
    t.string  "display_label",     :limit => 50
    t.string  "ontology_category", :limit => 50
    t.string  "ontology_value",    :limit => 50
    t.string  "design_type",       :limit => 15, :default => "", :null => false
    t.integer "is_deleted",                                      :null => false
  end

  create_table "events", :force => true do |t|
    t.integer  "array_design_id"
    t.integer  "experiment_id"
    t.string   "event_type",       :limit => 50,  :default => "", :null => false
    t.integer  "was_successful"
    t.string   "source_db",        :limit => 30
    t.string   "target_db",        :limit => 30
    t.datetime "start_time"
    t.datetime "end_time"
    t.string   "machine",          :limit => 50
    t.string   "operator",         :limit => 30
    t.string   "log_file",         :limit => 511
    t.integer  "jobregister_dbid", :limit => 15
    t.text     "comment"
    t.integer  "is_deleted",                                      :null => false
  end

  add_index "events", ["array_design_id"], :name => "array_design_id"
  add_index "events", ["experiment_id"], :name => "experiment_id"

  create_table "experiments", :force => true do |t|
    t.string   "accession"
    t.string   "name"
    t.integer  "user_id"
    t.integer  "checker_score"
    t.string   "software",                :limit => 100
    t.string   "status",                  :limit => 50
    t.integer  "data_warehouse_ready"
    t.datetime "date_last_edited"
    t.datetime "date_submitted"
    t.datetime "date_last_processed"
    t.integer  "in_curation"
    t.string   "curator",                 :limit => 30
    t.text     "comment"
    t.string   "experiment_type",         :limit => 30
    t.string   "miamexpress_login",       :limit => 30
    t.integer  "miamexpress_subid"
    t.integer  "is_affymetrix"
    t.integer  "is_uhts",                 :limit => 4
    t.integer  "use_native_datafiles",    :limit => 4
    t.integer  "is_mx_batchloader"
    t.integer  "is_deleted",                             :null => false
    t.integer  "miame_score"
    t.integer  "in_data_warehouse"
    t.integer  "num_submissions"
    t.text     "submitter_description"
    t.string   "curated_name"
    t.integer  "num_samples"
    t.integer  "num_hybridizations"
    t.integer  "has_raw_data"
    t.integer  "has_processed_data"
    t.integer  "has_gds",                 :limit => 4
    t.datetime "release_date"
    t.integer  "is_released"
    t.integer  "ae_miame_score"
    t.integer  "ae_data_warehouse_score"
    t.string   "migration_status"
    t.text     "migration_comment"
  end

  add_index "experiments", ["user_id"], :name => "user_id"

  create_table "experiments_factors", :force => true do |t|
    t.integer "experiment_id", :null => false
    t.integer "factor_id",     :null => false
  end

  add_index "experiments_factors", ["experiment_id"], :name => "experiment_id"
  add_index "experiments_factors", ["factor_id"], :name => "factor_id"

  create_table "experiments_loaded_data", :id => false, :force => true do |t|
    t.integer "experiment_id",  :null => false
    t.integer "loaded_data_id", :null => false
  end

  add_index "experiments_loaded_data", ["experiment_id"], :name => "experiment_id"
  add_index "experiments_loaded_data", ["loaded_data_id"], :name => "loaded_data_id"

  create_table "experiments_quantitation_types", :force => true do |t|
    t.integer "quantitation_type_id", :null => false
    t.integer "experiment_id",        :null => false
  end

  add_index "experiments_quantitation_types", ["quantitation_type_id"], :name => "quantitation_type_id"
  add_index "experiments_quantitation_types", ["experiment_id"], :name => "experiment_id"

  create_table "factors", :force => true do |t|
    t.string  "name",       :limit => 128, :default => "", :null => false
    t.integer "is_deleted",                                :null => false
  end

  create_table "loaded_data", :force => true do |t|
    t.string   "identifier",                              :default => "", :null => false
    t.string   "md5_hash",                  :limit => 35, :default => "", :null => false
    t.integer  "data_format_id",                                          :null => false
    t.integer  "is_deleted",                                              :null => false
    t.integer  "platform_id"
    t.integer  "needs_metrics_calculation",                               :null => false
    t.datetime "date_hashed"
  end

  add_index "loaded_data", ["data_format_id"], :name => "data_format_id"
  add_index "loaded_data", ["platform_id"], :name => "platform_loaded_data_ibfk_1"

  create_table "loaded_data_quality_metrics", :force => true do |t|
    t.decimal  "value",             :precision => 12, :scale => 5
    t.integer  "quality_metric_id",                                :null => false
    t.integer  "loaded_data_id",                                   :null => false
    t.datetime "date_calculated"
  end

  add_index "loaded_data_quality_metrics", ["quality_metric_id"], :name => "quality_metric_id"
  add_index "loaded_data_quality_metrics", ["loaded_data_id"], :name => "loaded_data_id"

  create_table "material_instances", :force => true do |t|
    t.integer "material_id",   :null => false
    t.integer "experiment_id", :null => false
  end

  add_index "material_instances", ["material_id"], :name => "material_id"
  add_index "material_instances", ["experiment_id"], :name => "experiment_id"

  create_table "materials", :force => true do |t|
    t.string  "display_label",     :limit => 50
    t.string  "ontology_category", :limit => 50
    t.string  "ontology_value",    :limit => 50
    t.integer "is_deleted",                      :null => false
  end

  create_table "meta", :primary_key => "name", :force => true do |t|
    t.string "value", :limit => 128, :default => "", :null => false
  end

  create_table "organism_instances", :force => true do |t|
    t.integer "organism_id",   :null => false
    t.integer "experiment_id", :null => false
  end

  add_index "organism_instances", ["organism_id"], :name => "organism_id"
  add_index "organism_instances", ["experiment_id"], :name => "experiment_id"

  create_table "organisms", :force => true do |t|
    t.string  "scientific_name", :limit => 50
    t.string  "common_name",     :limit => 50
    t.integer "accession"
    t.integer "taxon_id"
    t.integer "is_deleted",                    :null => false
  end

  add_index "organisms", ["taxon_id"], :name => "taxon_id"

  create_table "permissions", :force => true do |t|
    t.string  "name",       :limit => 40, :default => "", :null => false
    t.string  "info",       :limit => 80
    t.integer "is_deleted",                               :null => false
  end

  create_table "permissions_roles", :id => false, :force => true do |t|
    t.integer "role_id",       :null => false
    t.integer "permission_id", :null => false
  end

  add_index "permissions_roles", ["role_id"], :name => "role_id"
  add_index "permissions_roles", ["permission_id"], :name => "permission_id"

  create_table "pipelines", :force => true do |t|
    t.string  "submission_type",     :default => "",                            :null => false
    t.integer "instances_to_start",  :default => 1
    t.string  "checker_daemon"
    t.string  "exporter_daemon"
    t.integer "polling_interval",    :default => 5
    t.string  "checker_threshold",   :default => "ERROR_INNOCENT, ERROR_MIAME"
    t.string  "qt_filename"
    t.boolean "keep_protocol_accns", :default => false
    t.string  "accession_prefix"
    t.string  "pipeline_subdir"
  end

  create_table "platforms", :force => true do |t|
    t.string "name", :limit => 50, :default => "", :null => false
  end

  add_index "platforms", ["name"], :name => "name", :unique => true

  create_table "protocols", :force => true do |t|
    t.string   "accession",           :limit => 15
    t.string   "user_accession",      :limit => 100
    t.string   "expt_accession",      :limit => 15
    t.string   "name"
    t.datetime "date_last_processed"
    t.text     "comment"
    t.integer  "is_deleted",                         :null => false
  end

  add_index "protocols", ["accession"], :name => "accession", :unique => true

  create_table "quality_metrics", :force => true do |t|
    t.string "type",        :limit => 50, :default => "", :null => false
    t.text   "description"
  end

  add_index "quality_metrics", ["type"], :name => "type", :unique => true

  create_table "quantitation_types", :force => true do |t|
    t.string  "name",       :limit => 128, :default => "", :null => false
    t.integer "is_deleted",                                :null => false
  end

  create_table "roles", :force => true do |t|
    t.string  "name",       :limit => 40, :default => "", :null => false
    t.string  "info",       :limit => 80
    t.integer "is_deleted",                               :null => false
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer "user_id", :null => false
    t.integer "role_id", :null => false
  end

  add_index "roles_users", ["user_id"], :name => "user_id"
  add_index "roles_users", ["role_id"], :name => "role_id"

  create_table "spreadsheets", :force => true do |t|
    t.integer "experiment_id", :null => false
    t.string  "name"
    t.integer "is_deleted",    :null => false
  end

  add_index "spreadsheets", ["experiment_id"], :name => "experiment_id"

  create_table "taxons", :force => true do |t|
    t.string  "scientific_name", :limit => 50
    t.string  "common_name",     :limit => 50
    t.integer "accession"
    t.integer "is_deleted",                    :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "login",       :limit => 40,  :default => "", :null => false
    t.string   "name",        :limit => 40
    t.string   "password",    :limit => 40,  :default => "", :null => false
    t.string   "email",       :limit => 100
    t.datetime "modified_at"
    t.datetime "created_at"
    t.datetime "access"
    t.integer  "is_deleted",                                 :null => false
  end

  add_index "users", ["login"], :name => "login", :unique => true

end
