class CategoryController < ApplicationController
  model :category
  layout "admin"
  before_filter :login_required, :except => [ :show, :list ]

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def new
    @category = Category.new
  end

  def show
    @category = Category.find(params[:id])
  end

  def edit
    @category = Category.find(params[:id])
  end

  def list
    @category_pages, @categories = paginate(:category, 
					    :conditions => 'is_deleted=0',
					    :per_page => 20,
					    :order    => 'ontology_term')
  end

  def create

    # Set the initial deletion state to zero
    params[:category][:is_deleted] = 0
    @category = Category.new(params[:category])

    if @category.save
      flash[:notice] = 'Category was successfully created'
      redirect_to :action => 'list'
    else
      render_action 'new'
    end
  end

  def update
    @category = Category.find(@params[:id])
    if @category.update_attributes(@params[:category])
      flash[:notice] = 'Category was successfully updated'
      redirect_to :action => 'list'
    else
      render_action 'edit'
    end
  end
      
  def deprecate
    category = Category.find(@params[:id])
    if category.taxons.any? || category.designs.any? || category.materials.any?
      flash[:notice] = "Error: There are still taxons, designs or materials using #{ category.ontology_term }."
      redirect_to :action => 'list' 
    elsif category.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Category was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
