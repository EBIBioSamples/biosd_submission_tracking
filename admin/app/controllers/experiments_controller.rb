class ExperimentsController < ApplicationController

  include AutosubsCommon
  
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

    num_per_page = params[:list_all].to_i.zero? ? 30 : 1000000

    sql_where_clause = "is_deleted=0 and (accession is not null and accession!='')"

    @search_term = ""

    @search_term = strip_single_quotes(params[:search_term])
    
    sql_where_clause += search_sql(@search_term,"accession","comment")

    params[:page] ||= 1
    @experiments = Experiment.paginate :page => params[:page],
      :per_page   => num_per_page,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession'

  end

  def sample_subs
    num_per_page = params[:list_all].to_i.zero? ? 30 : 1000000

    sql_where_clause = "is_deleted=0 and experiment_type='ESD'"

    @search_term = ""

    @search_term = strip_single_quotes(params[:search_term])
    
    sql_where_clause += search_sql(@search_term,"accession","comment","name")

    params[:page] ||= 1
    @experiments = Experiment.paginate :page => params[:page],
      :per_page   => num_per_page,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession'
  end
  
  def today_list
    @time_now = Time.now;
    date_today       = @time_now.strftime("%Y-%m-%d %H:%M:%S");
    date_yesterday   = sprintf("%04d-%02d-%02d", @time_now.year, @time_now.month, @time_now.mday - 1);
    sql_where_clause = sprintf("is_deleted=0 and date_last_processed between '%s' and '%s'", date_yesterday, date_today);

    if params[:experiment_type]
      sql_where_clause += " and experiment_type='#{ params[:experiment_type] }'"
    end

    params[:page] ||= 1

#    @experiments = Experiment.paginate :page => params[:page],
#      :per_page   => 30,
#      :conditions => sql_where_clause.to_s,
#      :order      => 'date_last_processed DESC'

    # Include array designs too
    experiment_and_array_sql =  "select id, 'ArrayDesign' as object_type, date_last_processed from array_designs where #{sql_where_clause} 
    union select id, 'Experiment' as object_type, date_last_processed from experiments where #{sql_where_clause} order by date_last_processed DESC";

    @experiments = Experiment.paginate_by_sql experiment_and_array_sql, 
       :page => params[:page],
       :per_page   => 30
  end
  
  def migrations
    
    num_per_page = params[:list_all].to_i.zero? ? 30 : 1000000
    
    sql_where_clause = "migration_status is not null"
    
    if params[:migration_phase]
      # Filter list on selected migration status
      sql_where_clause = "migration_status = '#{ params[:migration_phase] }'"
    end
    
    @search_term = ""

    @search_term = strip_single_quotes(params[:search_term])
    
    sql_where_clause += search_sql(@search_term,"accession","migration_comment")
    
    params[:page] ||= 1
    @experiments = Experiment.paginate :page => params[:page],
      :per_page   => num_per_page,
      :conditions => sql_where_clause.to_s,
      :order      => 'accession'
  end
  
  def show
    @show_migration = params[:migration]
    @experiment = Experiment.find(params[:id])
  end
  
  def show_qm
    
    @experiment = Experiment.find(params[:id])

    acc = @experiment.accession
    pipeline = Pipeline.find(:first, 
                             :conditions => {:submission_type => @experiment.experiment_type})
    if pipeline
      subdir = pipeline.pipeline_subdir
    else
      acc =~ /E-([A-Z]{4})-\d/
      subdir = $1
    end
 
    dir_path = "/nfs/ma/ma-exp/EXPERIMENTS/"+subdir+"/"+acc+"/QM/QMreport/"
    if params[:file]
      show_pdf(:dir => dir_path, :file => params[:file], :acc => acc)
      return
    end
    
    @quality_metrics = @experiment.experiment_quality_metrics
    file_path = dir_path+"QMreport.html"
    if File.readable?(file_path)
      report = File.new(file_path, "r")
      input = report.read()
      input.scan(/src="([^"]*)"/){ |f|
        # Might need to do periodic clear out of images directory
        new_file = RAILS_ROOT + "/public/images/"+ acc + f[0]
        FileUtils.copy(dir_path+f[0], new_file)  
      }
      @content = input.gsub(/src="/, "src=\"/images/"+acc)
      @content = @content.gsub(/href="(\w*\.pdf)"/, 'href="'+params[:id]+'?file=\1"')   
      report.close
    else
      @content = "<h3>File "+file_path+" not found or unreadable</h3>"
    end
    
  end
  
  def show_pdf params
    download_name = params[:acc] + "_" + params[:file]
    send_file(params[:dir]+params[:file], :filename => download_name, :type => "application/pdf")  
  end

  def new
    @experiment = Experiment.new
  end

  def create

    # Set the initial deletion state to zero
    params[:experiment][:is_deleted] = 0
    @experiment = Experiment.new(params[:experiment])

    if @experiment.annotate(params[:annotation]) && @experiment.save
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
    common_params = {
                  :id              => @experiment.id,
                  :experiment_type => @experiment.experiment_type,
                  :search_term     => params[:search_term],
                  :page            => params[:page]
    }

    if @experiment.experiment_type == 'MIAMExpress'
      redirect_to common_params.merge({ 
                  :controller      => 'miamexps',
                  :action          => 'edit',})
    else
      redirect_to common_params.merge({
                  :controller      => 'tab2mages',
                  :action          => 'edit',})
    end
  end

  def update
    @experiment = Experiment.find(params[:id])
    if @experiment.annotate(params[:annotation]) && @experiment.update_attributes(params[:experiment])
      flash[:notice] = 'Experiment was successfully updated.'
      if params[:migration]
        redirect_to :action  => 'migrations',
            :page            => params[:page]
      else
        redirect_to :action => 'list',
	          :experiment_type => params[:experiment_type],
	          :search_term     => params[:search_term],
            :page            => params[:page]
      end
    else
      render :action => 'edit'
    end
  end

  def deprecate
    experiment = Experiment.find(params[:id])
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
