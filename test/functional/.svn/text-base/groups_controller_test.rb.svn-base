#!ruby
#
# c 2006 makalumedia
# 
# Group class functional tests
# 
# 2006-11-20  james.anderson
# 

require File.dirname(__FILE__) + '/../test_helper'
require 'groups_controller'

# Re-raise errors caught by the controller.
class GroupsController; def rescue_action(e) raise e end; end

class GroupsControllerTest < Test::Unit::TestCase
  fixtures :groups, :users, :groups_users, :roles_users

  def setup
    @controller = GroupsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # test creation with valid and invalid data
  # todo: duplicate title, unauthorized user
  def test_create_invalid_data
    login_as "anauthor"
    num_groups = Group.count

    # w/o data, the save fails and an edit page is returned.
    post :create, :group => {}, :user_id=> 1
    assert_response 200
    assert_template 'new'
  end
  
  def test_create_valid_data
    login_as "anauthor"
    num_groups = Group.count
    # a successful save redirects to the group list page
    post :create, :group => {:title=> "test group",
                             :scope=> User::SCOPE_PUBLIC,
                             :description=> "test group description"},
                  :user_id=> 1
    assert_response :redirect
    assert_redirected_to :action => 'show'
    assert_equal num_groups + 1, Group.count
  end

  def test_destroy_as_admin
    login_as "anadmin"
    assert_not_nil Group.find(1)
    post :destroy, :user_id=> 1, :group_id => 1
    assert_response :redirect
    assert_redirected_to(:controller=> 'users', :action => 'show')
    assert((group = Group.find(1)) && group.removed?)
  end

  def test_destroy_as_author
    login_as "anauthor"
    assert_not_nil Group.find(1)
    post :destroy, :user_id=> 1, :group_id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show'
    assert((group = Group.find(1)) && group.removed?)
  end

  def test_edit
    login_as "anauthor"
    get :edit, :user_id=> 1, :group_id => 1
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:group)    
    assert assigns(:group).valid?
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'list'
  end

  def test_list
    get :list
    assert_response :success
    assert_template 'list'
    assert_not_nil(@controller.instance_variable_get('@groups'))
  end

  def test_new
    login_as "anauthor"
    get :new,  :user_id=> 1
    assert_response :success
    assert_template 'new'
    assert_not_nil assigns(:group)
  end

  def test_rss_WCJ_GP_F05
    get :rss
    assert_response :success
    assert_not_nil(groups = assigns(:groups))
    assert(groups.length > 0)
    assert(groups.any?{|i| i.scope == User::SCOPE_PRIVATE} == false)
  end
  
  def test_show_public
    # no login
    get :show, :user_id=>1, :group_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end
  
  def test_title
    get :show, :user_id => 1, :group_id => 1
    assert_response :success
    assert_tag(:tag => "title", :parent => { :tag => "head" },
               :content=> Regexp.new("#{User.find(1).login} - \\[#{Group.find(1).title}\\] - #{Settings.page_title}"))
  end

  def test_show_private
    login_as "anauthor"
    get :show, :user_id=>1, :group_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_show_group_user_member
    login_as "reader1"
    get :show, :user_id=>1, :group_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_show_group_user_nonmember
    login_as "reader2"
    get :show, :user_id=>1, :group_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_show_group_guest
    # no login
    get :show, :user_id=>1, :group_id => 1
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:group)
    assert assigns(:group).valid?
  end

  def test_update
    login_as "anauthor"
    post :update, :user_id=> 1, :group_id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 1
  end

  # test invitation to site user
  def test_add_and_remove_WCJ_AEG_N03
    # first, login as an author and invite reader1, a site user to join an owned group
    login_as "anauthor"
    get :invite_member, :user_id => 1, :group_id=>2, :member_id=> 3
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 2
    assert(authentication = assigns(:authentication))
    # puts("invite_member flash: #{flash[:notice]}")

    # second, as reader1, join the group by following the mailed url,
    # which starts with a login request, which should redirect through GroupsController#add_member
    # and finish at GroupsController#show
    setup()
    @controller = AccountController.new
    post :login_to_group, :login=> 'reader1', :password=> 'test',
                          :group_id=>2, :member_id=> 3, :add_member=> authentication
    assert_redirected_to :action => 'add_member' #, :user_id => 1, :group_id => 2
    # puts(":login_to_group flash: #{flash.inspect}")
    @controller = GroupsController.new
    post :add_member, :user_id => 1, :group_id => 2, :member_id=>3, :add_member=> authentication
    # puts(":add_member flash: #{flash.inspect}")
    assert flash[:notice] =~ /.*successfully subscribed.*/
    group = Group.find(2)
    member = User.find(3)
    assert(group.users().include?(member))
    
    post :remove, :user_id => 1, :group_id=>2, :member_id=> 3
    assert_response :redirect
    assert_redirected_to :action => 'list' # removing does not redisplay the group, but rather the list of groups
    # puts("flash: #{flash[:notice]}")
    assert flash[:notice] =~ /.*successfully left the group.*/
    group = Group.find(2)
    assert_equal(group.users().include?(member), false)
  end

  # test add and remove journals
  # the owner can add a journal
  def test_add_and_remove_WCJ_AEG_N04
    login_as "anauthor"  # must be in the groups, public is not sufficient
    post :add_journal, :user_id => 1, :group_id=>2, :journal_id=> 1, :action=>'add_journaL'
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 2
    # puts("test_add_and_remove_WCJ_AEG_N04 flash: #{flash.inspect}")
    assert flash[:notice] =~ /.*Journal was successfully franchised.*/
    group = Group.find(2)
    journal = Journal.find(3)
    assert(group.journals().include?(journal))
    post :remove_journal, :user_id => 3, :journal_id=> 3, :group_id=>2
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 2
    group = Group.find(2)
    assert_equal(group.journals().include?(journal), false)
  end

  # test add and remove journals
  # a non-member cannot add a journal
  def test_add_and_remove_fails_WCJ_AEG_N04
    login_as "reader1"
    post :add_journal, :user_id => 3, :group_id=>2, :journal_id=> 3, :action=>'add_journaL'
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 2
    # puts("test_add_and_remove_fails_WCJ_AEG_N04 flash: #{flash.inspect}")
    assert flash[:error] =~ /.*Group does not permit access.*/
  end

  # test add and remove journals
  # a member can also _not_ add a journal through this resource/controller
  # they must use the journals controller as the journal is a resource in their domain
  def test_add_and_remove_as_member_WCJ_AEG_N04
    login_as "reader1"
    group = Group.find(2)
    user = User.find(3)
    group.users << user
    group.save!()
    # puts("user: #{user}")
    # puts("members: #{group.users}")
    post :add_journal, :user_id => 3, :group_id=>2, :journal_id=> 3, :action=>'add_journaL'
    assert_response :redirect
    assert_redirected_to :action => 'show', :group_id => 2
    # puts("test_add_and_remove_as_member_WCJ_AEG_N04 flash: #{flash.inspect}")
    assert flash[:error] =~ /.*Group does not permit access.*/
  end

  def test_add_and_remove_WCJ_AEG_A04
  end
end
