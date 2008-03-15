class TaxonController < ApplicationController

  layout "admin"
  before_filter :login_required, :except => [ :show, :list ]

  def new
    if Category.find(:all).any?
      @taxon = Taxon.new
    else
      flash[:notice] = 'Please create at least one category:'
      redirect_to :action => 'new', :controller => 'category'
    end
  end

  def edit
    @taxon = Taxon.find(params[:id])
  end

  def list
    params[:page] ||= 1
    @taxons = Taxon.paginate :page => params[:page], 
      :conditions => 'is_deleted=0',
      :per_page   => 20,
      :order      => 'scientific_name'
  end

  def category_table
    @taxons     = Taxon.find(:all, :conditions => 'is_deleted=0')
    @categories = Category.find(:all, :conditions => 'is_deleted=0')
  end

  def create

    # Set the initial deletion state to zero
    params[:taxon][:is_deleted] = 0
    @taxon = Taxon.new(params[:taxon])

    if @taxon.save
      flash[:notice] = 'Taxon was successfully created'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def update
    @taxon = Taxon.find(params[:id])
    
    # Fix for empty ids
    params[:taxon][:category_ids] ||= []

    if @taxon.update_attributes(params[:taxon])
      flash[:notice] = 'Taxon was successfully updated'
      redirect_to :action => 'list'
    else
      render :action => 'edit'
    end
  end
      
  def deprecate
    taxon = Taxon.find(params[:id])
    if taxon.organisms.any?
      flash[:notice] = "Error: There are still organisms in the #{ taxon.common_name } taxon."
      redirect_to :action => 'list' 
    elsif taxon.update_attribute(:is_deleted, 1)
      flash[:notice] = 'Taxon was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
