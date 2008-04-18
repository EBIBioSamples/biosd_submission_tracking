class MiamexpsController < ExperimentsController

  def list
    sql_where_clause = "is_deleted=0 and ( miamexpress_subid is not null || experiment_type='MIAMExpress' )"

    @search_term = ""

    if params[:search_term]

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      sql_where_clause += " and (accession like '#{ sql_search }'" +
	                  " or name like '%#{ sql_search }%'" +
	                  " or comment like '%#{ sql_search }%'" +
	                  " or miamexpress_login like '%#{ sql_search }%'" +
	                  " or miamexpress_subid like '#{ sql_search }')"
    end

    params[:page] ||= 1
    @experiments = Experiment.paginate :page => params[:page],
      :per_page   => 30,
      :conditions => sql_where_clause.to_s,
      :order      => 'miamexpress_subid DESC'

  end

  def edit
    @experiment  = Experiment.find(params[:id])
  end

end
