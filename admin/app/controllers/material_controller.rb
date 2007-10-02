class MaterialController < ApplicationController
  model :material
  scaffold :material
  layout "admin"
  before_filter :login_required, :except => [ :show, :list ]

  def new
    if Category.find_all.any?
      @material = Material.new
    else
      flash[:notice] = 'Please create at least one category:'
      redirect_to :action => 'new', :controller => 'category'
    end
  end

  def edit
    @material = Material.find(params[:id])
  end

  def list
    @material_pages, @materials = paginate(:material, 
					   :conditions => 'is_deleted=0',
                                           :per_page => 20,
                                           :order_by => 'display_label')
  end

  def create

    # Set the initial deletion state to zero
    params[:material][:is_deleted] = 0
    @material = Material.new(params[:material])

    if @material.save
      flash[:notice] = 'Material was successfully created'
      redirect_to :action => 'list'
    else
      render_action 'new'
    end
  end

  def update
    @material = Material.find(@params[:id])

    # Fix for empty ids
    @params[:material][:category_ids] ||= []

    if @material.update_attributes(@params[:material])
      flash[:notice] = 'Material was successfully updated'
      redirect_to :action => 'list'
    else
      render_action 'edit'
    end
  end
      
  def deprecate
    material = Material.find(@params[:id])
    if material.experiments.any?
      flash[:notice] = "Error: There are still experiments using the #{ material.ontology_value } material."
      redirect_to :action => 'list' 
    elsif material.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Material was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
