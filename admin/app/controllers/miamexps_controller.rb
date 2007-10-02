class MiamexpsController < ExperimentsController

  def list
    sql_where_clause = "miamexpress_subid is not null and is_deleted=0"

    @search_term = ""

    if params[:experiment_type]
      sql_where_clause += " and experiment_type='#{ params[:experiment_type] }'"
    end

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

    @experiment_pages, @experiments = paginate :experiments,
      :per_page   => 30,
      :conditions => sql_where_clause.to_s,
      :order      => 'miamexpress_subid DESC'

  end

  def edit
    @experiment  = Experiment.find(params[:id])
    @search_term = params[:search_term]
    @page        = params[:page]
  end

end
