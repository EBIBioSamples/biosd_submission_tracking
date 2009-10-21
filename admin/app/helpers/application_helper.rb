# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def migration_status_drop_down object_type
    content_tag("td", select(object_type,"migration_status", ["Awaiting migration","Ready to migrate","Migration failed","Waiting","Checking failed","Complete","Migration cancelled"]))
  end
end
