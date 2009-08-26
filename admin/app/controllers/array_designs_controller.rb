class ArrayDesignsController < ApplicationController

  layout "admin"
  before_filter :login_required

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list

    sql_where_clause = "is_deleted=0 and miamexpress_subid is not null"
    order_by = 'miamexpress_subid DESC'

    if params[:array_type] == "geo"
        sql_where_clause = "is_deleted=0 and accession like 'A-GEOD-%'"
        order_by = 'accession DESC'
    end
    
    @array_type = params[:array_type]
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
    @array_designs = ArrayDesign.paginate :page => params[:page],
      :per_page   => 40,
      :conditions => sql_where_clause.to_s,
      :order      => order_by
  end

  def list_all

    num_per_page = params[:list_all].to_i.zero? ? 30 : 1000000

    sql_where_clause = "is_deleted=0 and (accession is not null and accession!='')"

    @search_term = ""

    # Don't search with an empty string.
    if params[:search_term] && !params[:search_term].eql?("")

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      sql_where_clause += " and accession like '#{ sql_search }'" +
	                  " or comment like '%#{ sql_search }%'"

    end

    params[:page] ||= 1
    @array_designs = ArrayDesign.paginate :page => params[:page],
      :per_page   => num_per_page,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession'

  end

  def show
    @array_design = ArrayDesign.find(params[:id])
  end

  def new
    @array_design = ArrayDesign.new
  end

  def edit
    @array_design = ArrayDesign.find(params[:id])
  end

  def create

    # Set the initial deletion state to zero
    params[:array_design][:is_deleted] = 0
    @array_design = ArrayDesign.new(params[:array_design])

    if @array_design.save
      flash[:notice] = 'ArrayDesign was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def update
    @array_design = ArrayDesign.find(params[:id])
    if @array_design.update_attributes(params[:array_design])
      flash[:notice] = 'ArrayDesign was successfully updated.'
      redirect_to :action => 'list_all',
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    else
      render :action => 'edit'
    end
  end

  def deprecate
    array_design = ArrayDesign.find(params[:id])
    if array_design.experiments.any?
      flash[:notice] = "Error: There are still experiments using #{ array_design.accession }."
      redirect_to :action => 'list' 
    elsif array_design.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Array design was successfully deleted'
      redirect_to :action => 'list',
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    end
  end

end
