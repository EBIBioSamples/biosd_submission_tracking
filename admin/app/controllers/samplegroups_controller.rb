class SamplegroupsController < ApplicationController

  layout "admin"
  before_filter :login_required

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :update ],
         :redirect_to => { :action => :list }

  def list

    sql_where_clause = "is_deleted=0"

    @search_term = ""

    if params[:search_term]

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      sql_where_clause += " and (accession like '#{ sql_search }'" +
	                  " or user_accession like '#{ sql_search }'" +
	                  " or source_repository like '#{ sql_search }'" +
	                  " or project_name like '#{ sql_search }'" +
	                  " or comment like '%#{ sql_search }%'" +
	                  " or submission_accession like '#{ sql_search }')"
    end

    if params[:submission_accession]
        sql_where_clause += " and submission_accession = '#{ params[:submission_accession]}'"
    end
    
    params[:page] ||= 1
    @samplegroups = SampleGroup.paginate :page => params[:page],
      :per_page   => 40,
      :conditions => sql_where_clause.to_s,
      :order      => 'id DESC'

  end

end