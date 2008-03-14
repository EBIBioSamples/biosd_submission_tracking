class ProtocolsController < ApplicationController

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

    sql_where_clause = "is_deleted=0"

    @search_term = ""

    if params[:search_term]

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      sql_where_clause += " and (accession like '#{ sql_search }'" +
	                  " or user_accession like '%#{ sql_search }%'" +
	                  " or name like '%#{ sql_search }%'" +
	                  " or comment like '%#{ sql_search }%'" +
	                  " or expt_accession like '#{ sql_search }')"
    end

    @protocols = Protocol.paginate :page => params[:page],
      :per_page   => 40,
      :conditions => sql_where_clause.to_s,
      :order      => 'id DESC'

  end

  def show
    @protocol = Protocol.find(params[:id])
  end

  def new
    @protocol = Protocol.new
  end

  def edit
    @protocol = Protocol.find(params[:id])
    @search_term  = params[:search_term]
    @page         = params[:page]
  end

  def create

    # Set the initial deletion state to zero
    params[:protocol][:is_deleted] = 0
    @protocol = Protocol.new(params[:protocol])

    if @protocol.save
      flash[:notice] = 'Protocol was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def update
    @protocol = Protocol.find(params[:id])
    if @protocol.update_attributes(params[:protocol])
      flash[:notice] = 'Protocol was successfully updated.'
      redirect_to :action => 'list',
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    else
      render :action => 'edit'
    end
  end

  def deprecate
    Protocol.find(params[:id]).update_attribute(:is_deleted, 1)
      flash[:notice] = 'Protocol was successfully deleted.'
    redirect_to :action => 'list',
	        :search_term     => params[:search_term],
                :page            => params[:page]
  end

end
