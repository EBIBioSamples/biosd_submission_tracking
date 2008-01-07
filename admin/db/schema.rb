# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define() do

  create_table "array_designs", :force => true do |t|
    t.column "miamexpress_subid", :integer
    t.column "accession", :string
    t.column "name", :string
    t.column "miamexpress_login", :string, :limit => 50
    t.column "status", :string, :limit => 50
    t.column "data_warehouse_ready", :string, :limit => 15
    t.column "date_last_processed", :datetime
    t.column "comment", :text
    t.column "is_deleted", :integer, :default => 0, :null => false
    t.column "miame_score", :integer
    t.column "in_data_warehouse", :integer
    t.column "annotation_source", :string, :limit => 50
    t.column "annotation_version", :string, :limit => 50
    t.column "biomart_table_name", :string, :limit => 50
    t.column "release_date", :datetime
    t.column "is_released", :integer
  end

  add_index "array_designs", ["miamexpress_subid"], :name => "miamexpress_subid", :unique => true

  create_table "array_designs_experiments", :force => true do |t|
    t.column "array_design_id", :integer, :default => 0, :null => false
    t.column "experiment_id", :integer, :default => 0, :null => false
  end

  add_index "array_designs_experiments", ["array_design_id"], :name => "array_design_id"
  add_index "array_designs_experiments", ["experiment_id"], :name => "experiment_id"

  create_table "array_designs_organisms", :force => true do |t|
    t.column "organism_id", :integer, :default => 0, :null => false
    t.column "array_design_id", :integer, :default => 0, :null => false
  end

  add_index "array_designs_organisms", ["organism_id"], :name => "organism_id"
  add_index "array_designs_organisms", ["array_design_id"], :name => "array_design_id"

  create_table "categories", :force => true do |t|
    t.column "ontology_term", :string, :limit => 50
    t.column "display_label", :string, :limit => 50
    t.column "is_common", :integer
    t.column "is_bmc", :integer
    t.column "is_fv", :integer
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "categories_designs", :id => false, :force => true do |t|
    t.column "category_id", :integer, :default => 0, :null => false
    t.column "design_id", :integer, :default => 0, :null => false
  end

  add_index "categories_designs", ["category_id"], :name => "category_id"
  add_index "categories_designs", ["design_id"], :name => "design_id"

  create_table "categories_materials", :id => false, :force => true do |t|
    t.column "category_id", :integer, :default => 0, :null => false
    t.column "material_id", :integer, :default => 0, :null => false
  end

  add_index "categories_materials", ["category_id"], :name => "category_id"
  add_index "categories_materials", ["material_id"], :name => "material_id"

  create_table "categories_taxons", :id => false, :force => true do |t|
    t.column "category_id", :integer, :default => 0, :null => false
    t.column "taxon_id", :integer, :default => 0, :null => false
  end

  add_index "categories_taxons", ["category_id"], :name => "category_id"
  add_index "categories_taxons", ["taxon_id"], :name => "taxon_id"

  create_table "data_files", :force => true do |t|
    t.column "experiment_id", :integer, :default => 0, :null => false
    t.column "name", :string
    t.column "is_unpacked", :integer
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "data_files", ["experiment_id"], :name => "experiment_id"

  create_table "design_instances", :force => true do |t|
    t.column "design_id", :integer, :default => 0, :null => false
    t.column "experiment_id", :integer, :default => 0, :null => false
  end

  add_index "design_instances", ["design_id"], :name => "design_id"
  add_index "design_instances", ["experiment_id"], :name => "experiment_id"

  create_table "designs", :force => true do |t|
    t.column "display_label", :string, :limit => 50
    t.column "ontology_category", :string, :limit => 50
    t.column "ontology_value", :string, :limit => 50
    t.column "design_type", :string, :limit => 15, :default => "", :null => false
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "events", :force => true do |t|
    t.column "array_design_id", :integer
    t.column "experiment_id", :integer
    t.column "event_type", :string, :limit => 50, :default => "", :null => false
    t.column "was_successful", :integer
    t.column "source_db", :string, :limit => 30
    t.column "target_db", :string, :limit => 30
    t.column "start_time", :datetime
    t.column "end_time", :datetime
    t.column "machine", :string, :limit => 50
    t.column "operator", :string, :limit => 30
    t.column "log_file", :string
    t.column "jobregister_dbid", :integer, :limit => 15
    t.column "comment", :text
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "events", ["array_design_id"], :name => "array_design_id"
  add_index "events", ["experiment_id"], :name => "experiment_id"

  create_table "experiments", :force => true do |t|
    t.column "accession", :string
    t.column "name", :string
    t.column "user_id", :integer
    t.column "checker_score", :integer
    t.column "software", :string, :limit => 100
    t.column "status", :string, :limit => 50
    t.column "data_warehouse_ready", :integer
    t.column "date_last_edited", :datetime
    t.column "date_submitted", :datetime
    t.column "date_last_processed", :datetime
    t.column "in_curation", :integer
    t.column "curator", :string, :limit => 30
    t.column "comment", :text
    t.column "experiment_type", :string, :limit => 30
    t.column "miamexpress_login", :string, :limit => 30
    t.column "miamexpress_subid", :integer
    t.column "is_affymetrix", :integer
    t.column "is_mx_batchloader", :integer
    t.column "is_deleted", :integer, :default => 0, :null => false
    t.column "miame_score", :integer
    t.column "in_data_warehouse", :integer
    t.column "num_submissions", :integer
    t.column "submitter_description", :text
    t.column "curated_name", :string
    t.column "num_samples", :integer
    t.column "num_hybridizations", :integer
    t.column "has_raw_data", :integer
    t.column "has_processed_data", :integer
    t.column "release_date", :datetime
    t.column "is_released", :integer
    t.column "ae_miame_score", :integer
    t.column "ae_data_warehouse_score", :integer
  end

  add_index "experiments", ["user_id"], :name => "user_id"

  create_table "experiments_factors", :force => true do |t|
    t.column "experiment_id", :integer, :default => 0, :null => false
    t.column "factor_id", :integer, :default => 0, :null => false
  end

  add_index "experiments_factors", ["experiment_id"], :name => "experiment_id"
  add_index "experiments_factors", ["factor_id"], :name => "factor_id"

  create_table "experiments_quantitation_types", :force => true do |t|
    t.column "quantitation_type_id", :integer, :default => 0, :null => false
    t.column "experiment_id", :integer, :default => 0, :null => false
  end

  add_index "experiments_quantitation_types", ["quantitation_type_id"], :name => "quantitation_type_id"
  add_index "experiments_quantitation_types", ["experiment_id"], :name => "experiment_id"

  create_table "factors", :force => true do |t|
    t.column "name", :string, :limit => 128, :default => "", :null => false
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "material_instances", :force => true do |t|
    t.column "material_id", :integer, :default => 0, :null => false
    t.column "experiment_id", :integer, :default => 0, :null => false
  end

  add_index "material_instances", ["material_id"], :name => "material_id"
  add_index "material_instances", ["experiment_id"], :name => "experiment_id"

  create_table "materials", :force => true do |t|
    t.column "display_label", :string, :limit => 50
    t.column "ontology_category", :string, :limit => 50
    t.column "ontology_value", :string, :limit => 50
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "meta", :id => false, :force => true do |t|
    t.column "name", :string, :limit => 128, :default => "", :null => false
    t.column "value", :string, :limit => 128, :default => "", :null => false
  end

  create_table "organism_instances", :force => true do |t|
    t.column "organism_id", :integer, :default => 0, :null => false
    t.column "experiment_id", :integer, :default => 0, :null => false
  end

  add_index "organism_instances", ["organism_id"], :name => "organism_id"
  add_index "organism_instances", ["experiment_id"], :name => "experiment_id"

  create_table "organisms", :force => true do |t|
    t.column "scientific_name", :string, :limit => 50
    t.column "common_name", :string, :limit => 50
    t.column "accession", :integer
    t.column "taxon_id", :integer
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "organisms", ["taxon_id"], :name => "taxon_id"

  create_table "permissions", :force => true do |t|
    t.column "name", :string, :limit => 40, :default => "", :null => false
    t.column "info", :string, :limit => 80
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "permissions_roles", :id => false, :force => true do |t|
    t.column "role_id", :integer, :default => 0, :null => false
    t.column "permission_id", :integer, :default => 0, :null => false
  end

  add_index "permissions_roles", ["role_id"], :name => "role_id"
  add_index "permissions_roles", ["permission_id"], :name => "permission_id"

  create_table "protocols", :force => true do |t|
    t.column "accession", :string, :limit => 15
    t.column "user_accession", :string, :limit => 100
    t.column "expt_accession", :string, :limit => 15
    t.column "name", :string
    t.column "date_last_processed", :datetime
    t.column "comment", :text
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "protocols", ["accession"], :name => "accession", :unique => true

  create_table "quantitation_types", :force => true do |t|
    t.column "name", :string, :limit => 128, :default => "", :null => false
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "roles", :force => true do |t|
    t.column "name", :string, :limit => 40, :default => "", :null => false
    t.column "info", :string, :limit => 80
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.column "user_id", :integer, :default => 0, :null => false
    t.column "role_id", :integer, :default => 0, :null => false
  end

  add_index "roles_users", ["user_id"], :name => "user_id"
  add_index "roles_users", ["role_id"], :name => "role_id"

  create_table "spreadsheets", :force => true do |t|
    t.column "experiment_id", :integer, :default => 0, :null => false
    t.column "name", :string
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "spreadsheets", ["experiment_id"], :name => "experiment_id"

  create_table "taxons", :force => true do |t|
    t.column "scientific_name", :string, :limit => 50
    t.column "common_name", :string, :limit => 50
    t.column "accession", :integer
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  create_table "users", :force => true do |t|
    t.column "login", :string, :limit => 40, :default => "", :null => false
    t.column "name", :string, :limit => 40
    t.column "password", :string, :limit => 40, :default => "", :null => false
    t.column "email", :string, :limit => 100
    t.column "modified_at", :datetime
    t.column "created_at", :datetime
    t.column "access", :datetime
    t.column "is_deleted", :integer, :default => 0, :null => false
  end

  add_index "users", ["login"], :name => "login", :unique => true

end
