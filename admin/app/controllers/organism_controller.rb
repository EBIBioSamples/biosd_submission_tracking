class OrganismController < ApplicationController

  layout "admin"
  before_filter :login_required, :except => [ :show, :list ]

  def new
    if Taxon.find(:all).any?
      @organism = Organism.new
    else
      flash[:notice] = 'Please create at least one taxon:'
      redirect_to :action => 'new', :controller => 'taxon'
    end
  end

  def edit
    @organism = Organism.find(params[:id])
  end

  def list
    @organisms = Organism.paginate :page => params[:page], 
      :conditions => 'is_deleted=0',
      :per_page   => 20,
      :order      => 'scientific_name'
  end

  def create

    # Set the initial deletion state to zero
    params[:organism][:is_deleted] = 0
    @organism = Organism.new(params[:organism])

    if @organism.save
      flash[:notice] = 'Organism was successfully created'
      redirect_to :action => 'list'
    else
      render_action 'new'
    end
  end

  def update
    @organism = Organism.find(params[:id])
    if @organism.update_attributes(params[:organism])
      flash[:notice] = 'Organism was successfully updated'
      redirect_to :action => 'list'
    else
      render_action 'edit'
    end
  end
      
  def deprecate
    organism = Organism.find(params[:id])
    if organism.experiments.any?
      flash[:notice] = "Error: There are still experiments using #{ organism.scientific_name }."
      redirect_to :action => 'list' 
    elsif organism.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Organism was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
