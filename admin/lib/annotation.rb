module Annotation

  def annotate(annotation)

    if annotation
      self.map_to_designs(annotation[:design_ids])
      self.map_to_materials(annotation[:material_ids])
      self.map_to_organisms(annotation[:organism_ids])
    else

      # empty annotation, so pass empty arrays to the mapping methods
      self.map_to_designs([])
      self.map_to_materials([])
      self.map_to_organisms([])
    end

    true # I.e, nothing failed (FIXME to actually test this)...

  end

  def map_to_designs(new_design_ids)

    if new_design_ids && new_design_ids.any?

      # Remove unwanted designs
      self.design_instances.each do |old|
	unless new_design_ids.include?(old.design_id)
	  old.destroy
	end
      end

      # Add new designs
      new_design_ids.each do |newid|
	unless self.design_instances.find(:first, :conditions => "design_id = " + newid.to_s)	  
	  design = Design.find(newid)
	  self.design_instances.create(:design => design)
	end
      end

    else
      self.design_instances.destroy_all
    end
    
  end

  def map_to_materials(new_material_ids)

    if new_material_ids && new_material_ids.any?

      # Remove unwanted materials
      self.material_instances.each do |old|
	unless new_material_ids.include?(old.material_id)
	  old.destroy
	end
      end

      # Add new materials
      new_material_ids.each do |newid|
	unless self.material_instances.find(:first, :conditions => "material_id = " + newid.to_s)	  
	  material = Material.find(newid)
	  self.material_instances.create(:material => material)
	end
      end

    else
      self.material_instances.destroy_all
    end
    
  end

  def map_to_organisms(new_organism_ids)

    if new_organism_ids && new_organism_ids.any?

      # Remove unwanted organisms
      self.organism_instances.each do |old|
	unless new_organism_ids.include?(old.organism_id)
	  old.destroy
	end
      end

      # Add new organisms
      new_organism_ids.each do |newid|
	unless self.organism_instances.find(:first, :conditions => "organism_id = " + newid.to_s)	  
	  organism = Organism.find(newid)
	  self.organism_instances.create(:organism => organism)
	end
      end

    else
      self.organism_instances.destroy_all
    end
    
  end

end
