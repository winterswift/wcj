
VERSIONS[__FILE__] = "$Id: roles_controller.rb 435 2006-12-25 21:55:29Z james $"

class RolesController < ApplicationController
  access_rule 'admin'
  
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  # verify :method => :post, :only => [ :destroy, :create, :update ],
  #        :redirect_to => { :action => :list }

  def index
    list
    render :action => 'list'
  end

  def list
    @role_pages, @roles = paginate :roles, :per_page => 10
  end

  def show
    @role = Role.find(params[:id])
  end

#  no modification are allowed for roles.
#  def new
#    @role = Role.new
#  end
#
#  def create
#    @role = Role.new(params[:role])
#    if @role.save
#      flash[:notice] = 'Role was successfully created.'
#      redirect_to :action => 'list'
#    else
#      render :action => 'new'
#    end
#  end
#
#  def edit
#    @role = Role.find(params[:id])
#  end
#
#  def update
#    @role = Role.find(params[:id])
#    if @role.update_attributes(params[:role])
#      flash[:notice] = 'Role was successfully updated.'
#      redirect_to :action => 'show', :id => @role
#    else
#      render :action => 'edit'
#    end
#  end
#
#  def destroy
#    Role.find(params[:id]).destroy
#    redirect_to :action => 'list'
#  end
end
