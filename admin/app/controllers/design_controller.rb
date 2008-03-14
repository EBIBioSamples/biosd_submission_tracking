class DesignController < ApplicationController

  layout "admin"
  before_filter :login_required, :except => [ :show, :list ]

  def new
    if Category.find(:all).any?
      @design = Design.new
    else
      flash[:notice] = 'Please create at least one category:'
      redirect_to :action => 'new', :controller => 'category'
    end
  end

  def edit
    @design = Design.find(params[:id])
  end

  def list
    @designs = Design.paginate :page => params[:page], 
      :conditions => 'is_deleted=0',
      :per_page   => 20,
      :order      => 'display_label'
  end

  def create

    # Set the initial deletion state to zero
    params[:design][:is_deleted] = 0
    @design = Design.new(params[:design])

    if @design.save
      flash[:notice] = 'Design was successfully created'
      redirect_to :action => 'list'
    else
      render_action 'new'
    end
  end

  def update
    @design = Design.find(params[:id])

    # Fix for empty ids
    params[:design][:category_ids] ||= []

    if @design.update_attributes(params[:design])
      flash[:notice] = 'Design was successfully updated'
      redirect_to :action => 'list'
    else
      render_action 'edit'
    end
  end
      
  def deprecate
    design = Design.find(params[:id])
    if design.experiments.any?
      flash[:notice] = "Error: There are still experiments using the #{ design.ontology_value } design."
      redirect_to :action => 'list' 
    elsif design.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Design was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
