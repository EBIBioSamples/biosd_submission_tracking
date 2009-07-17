class Tab2magesController < ExperimentsController

  def list

    sql_where_clause = "is_deleted=0"

    @search_term = ""

    if params[:experiment_type]
      sql_where_clause += " and experiment_type='#{ params[:experiment_type] }'"
    end

    if params[:has_gds]
      sql_where_clause += " and has_gds='#{ params[:has_gds] }'"
    end

    if params[:search_term]

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      users = User.find(:all, :conditions => "login like '%#{ sql_search }%'")
      user_clause = users.any? ? " or user_id in (#{ users.collect{|u| u.id}.join(',') })" : ""

      sql_where_clause += " and (accession like '#{ sql_search }'" +
	                  " or comment like '%#{ sql_search }%'" +
	                  " or id like '#{ sql_search }'" +
	                  " or miamexpress_login like '%#{ sql_search }%'" +
	                  " or name like '%#{ sql_search }%'#{ user_clause }" + 
                          " or status like '%#{ sql_search }%')"
    end
    
    params[:page] ||= 1
    @experiments = Experiment.paginate :page => params[:page],
      :per_page   => 30,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession is null asc, accession="" asc, cast(substr(accession,8,10) as signed integer) desc'

  end

  def edit
    @experiment  = Experiment.find(params[:id])
  end

end
