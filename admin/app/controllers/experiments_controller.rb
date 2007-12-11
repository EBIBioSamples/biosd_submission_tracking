class ExperimentsController < ApplicationController
  model :experiment
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

    sql_where_clause = "is_deleted=0 and (accession is not null and accession!='')"

    @search_term = ""

    if params[:search_term]

      # Strip single quotes, otherwise they will cause a crash.
      @search_term = params[:search_term].gsub(/\'/, "")

      # Silently allow asterisk wildcards
      sql_search = @search_term.gsub(/\*/, "%").gsub(/\?/, "_")

      sql_where_clause += " and accession like '#{ sql_search }'"

    end

    @experiment_pages, @experiments = paginate :experiments,
      :per_page   => 30,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession is null asc, accession="" asc, cast(substr(accession,8,10) as signed integer) desc'

  end

  def today_list
    @time_now = Time.now;
    date_today       = @time_now.strftime("%Y-%m-%d %H:%M:%S");
    date_yesterday   = sprintf("%04d-%02d-%02d", @time_now.year, @time_now.month, @time_now.mday - 1);
    sql_where_clause = sprintf("is_deleted=0 and date_last_processed between '%s' and '%s'", date_yesterday, date_today);

    if params[:experiment_type]
      sql_where_clause += " and experiment_type='#{ params[:experiment_type] }'"
    end

    @experiment_pages, @experiments = paginate :experiments,
      :per_page   => 30,
      :conditions => sql_where_clause.to_s,
      :order      => 'date_last_processed DESC'
  end

  def show
    @experiment = Experiment.find(params[:id])
  end

  def new
    @experiment = Experiment.new
  end

  def create

    # Set the initial deletion state to zero
    params[:experiment][:is_deleted] = 0
    @experiment = Experiment.new(params[:experiment])

    if @experiment.annotate(@params[:annotation]) && @experiment.save
      flash[:notice] = "#{params[:experiment][:experiment_type]} experiment was successfully created."
      redirect_to :action          => 'list',
	          :experiment_type => params[:experiment][:experiment_type]
    else
      render :action => 'new'
    end
  end

  def edit

    # Abstract superclass method dispatches edit calls to the relevant subclass.
    @experiment  = Experiment.find(params[:id])
    @search_term = params[:search_term]
    @page        = params[:page]
    if @experiment.experiment_type == 'MIAMExpress'
      redirect_to :controller      => 'miamexps',
                  :action          => 'edit',
                  :id              => @experiment.id,
                  :experiment_type => @experiment.experiment_type,
                  :search_term     => @search_term,
                  :page            => @page
    else
      redirect_to :controller      => 'tab2mages',
                  :action          => 'edit',
                  :id              => @experiment.id,
                  :experiment_type => @experiment.experiment_type,
                  :search_term     => @search_term,
                  :page            => @page
    end
  end

  def update
    @experiment = Experiment.find(params[:id])
    if @experiment.annotate(@params[:annotation]) && @experiment.update_attributes(@params[:experiment])
      flash[:notice] = 'Experiment was successfully updated.'
      redirect_to :action => 'list',
	          :experiment_type => params[:experiment_type],
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    else
      render :action => 'edit'
    end
  end

  def deprecate
    experiment = Experiment.find(@params[:id])
    if experiment.spreadsheets.find(:all, :conditions => "is_deleted=0").any?
      flash[:notice] = "Error: There are still spreadsheets attached to the experiment: #{ experiment.name }"
      redirect_to :action          => 'list', 
	          :experiment_type => params[:experiment_type],
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    elsif experiment.data_files.find(:all, :conditions => "is_deleted=0").any?
      flash[:notice] = "Error: There are still data_files attached to the experiment: #{ experiment.name }"
      redirect_to :action          => 'list', 
	          :experiment_type => params[:experiment_type],
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    elsif experiment.accession?
      flash[:notice] = "Error: This experiment has been assigned an accession number, and cannot be deleted: #{ experiment.name }"
      redirect_to :action => 'list', 
	          :experiment_type => params[:experiment_type],
	          :search_term     => params[:search_term],
                  :page            => params[:page]
    elsif experiment.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Experiment was successfully deleted'
      redirect_to :action => 'list',
	          :experiment_type => params[:experiment_type],
  	          :search_term     => params[:search_term],
                  :page            => params[:page]
    end
  end

end
