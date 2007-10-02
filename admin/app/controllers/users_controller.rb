class UsersController < ApplicationController
  model :user
  scaffold :user
  layout "admin"
  before_filter :login_required

  def list
    @user_pages, @users = paginate :users,
      :conditions => 'is_deleted=0',
      :order     => 'login',
      :per_page => 100
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    redirect_to :controller => 'account', :action => 'signup'
    @user = User.new
  end

  def create

    # Set the initial deletion state to zero
    params[:user][:is_deleted] = 0
    @user = User.new(params[:user])

    if @user.save
      flash[:notice] = 'User was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])

    # FIXME the Time call below returns the correct string, but it is
    # not stored correctly in the database.
    if @user.update_attributes(@params[:user]) \
      && @user.update_attribute(:modified_at, Time.now.getutc.iso8601.to_s)
      flash[:notice] = 'User was successfully updated.'
      redirect_to :action => 'list'
    else
      render :action => 'edit'
    end
  end

  def deprecate
    user = User.find(@params[:id])
    if user.experiments.any?
      flash[:notice] = "Error: There are still experiments attached to user #{ user.login }."
      redirect_to :action => 'list' 
    elsif user.update_attribute(:is_deleted, 1)
      flash[:notice] = 'User was successfully deleted'
      redirect_to :action => 'list'
    end
  end

end
