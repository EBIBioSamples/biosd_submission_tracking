module AutosubsCommon

  def strip_single_quotes(term)
    if term && !term.eql?("")
      return term.gsub(/\'/, "")
    end
    return ""
  end
  
  def search_sql(*input)
    search_term = input.shift
    if search_term && !search_term.eql?("")

      # Strip single quotes, otherwise they will cause a crash.
      term = strip_single_quotes(search_term)

      # Silently allow asterisk wildcards
      sql_search = term.gsub(/\*/, "%").gsub(/\?/, "_")
      
      first = input.shift
      
      sql = " and #{ first } like '%#{ sql_search }%'"
      
      input.each do |field|
        sql += " or #{ field } like '%#{ sql_search }%'"
      end
      
      return sql
    end
    return ""
  end
  
end