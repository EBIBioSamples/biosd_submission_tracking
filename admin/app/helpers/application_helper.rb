# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def migration_status_drop_down object_type
    content_tag("td", select(object_type,"migration_status", ["Awaiting migration","Ready to migrate","Migration failed","Waiting","Checking failed","Complete","Migration cancelled", "Exported directly to AE2"]))
  end
  
  def atlas_score_codes
      html = ""
      html = <<HTML
<div>
Atlas fail score codes:
<ul>
<li>1 - data files are missing</li>
<li>2 - array design is not in Atlas</li>
<li>3 - experiment has a type not eligible for Atlas</li>
<li>4 - two-channel experiment</li>
<li>5 - does not have factor values</li>
<li>6 - experiment doesn't have replicates for at least 1 factor type</li>
<li>7 - factor type or characteristics types are not from controlled vocabulary</li>
<li>8 - factor type or characteristics types are repeated</li>
</ul>
</div>      
HTML
  end
end
