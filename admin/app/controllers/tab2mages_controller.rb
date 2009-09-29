class Tab2magesController < ExperimentsController

  include AutosubsCommon
  
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

      @search_term = strip_single_quotes(params[:search_term])
    
      sql_where_clause += search_sql(@search_term,"accession","name","comment","id","miamexpress_subid","status", "miamexpress_login")

      # Search in user names too
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")
      users = User.find(:all, :conditions => "login like '%#{ sql_search }%'")
      user_clause = users.any? ? " or user_id in (#{ users.collect{|u| u.id}.join(',') })" : ""

      sql_where_clause += user_clause  
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
