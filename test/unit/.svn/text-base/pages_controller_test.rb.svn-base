#
# unit test for PagesController exercises collection retrieval without request

require File.dirname(__FILE__) + '/../test_helper'
require 'pages_controller'

# Re-raise errors caught by the controller.
class PagesController; def rescue_action(e) raise e end; end


class PagesControllerUnitTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :users, :groups_users, :roles_users, :entries
  
  def setup
    @controller = PagesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_entries
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_entries_with_params
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.entries({:page_size=> 2, :entry_page=> 1, :require_photo=> true})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_entries_with_user
    login_as "anauthor"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_entries_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_entries_with_user_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_groups
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.groups({})
    assert(@controller.instance_variable_get(:@groups).kind_of?(Array))
    assert(@controller.instance_variable_get(:@group_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_groups_with_params
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.groups({:page_size=> 2, :group_page=> 1})
    assert(@controller.instance_variable_get(:@groups).kind_of?(Array))
    assert(@controller.instance_variable_get(:@group_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_groups_with_user
    login_as "anauthor"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.groups({})
    assert(@controller.instance_variable_get(:@groups).kind_of?(Array))
    assert(@controller.instance_variable_get(:@group_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_groups_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.groups({})
    assert(@controller.instance_variable_get(:@groups).kind_of?(Array))
    assert(@controller.instance_variable_get(:@group_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_groups_with_user_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.groups({})
    assert(@controller.instance_variable_get(:@groups).kind_of?(Array))
    assert(@controller.instance_variable_get(:@group_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_journals
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.journals({})
    assert(@controller.instance_variable_get(:@journals).kind_of?(Array))
    assert(@controller.instance_variable_get(:@journal_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_journals_with_params
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.journals({:page_size=> 2, :journal_page=> 1})
    assert(@controller.instance_variable_get(:@journals).kind_of?(Array))
    assert(@controller.instance_variable_get(:@journal_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_journals_with_user
    login_as "anauthor"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.journals({})
    assert(@controller.instance_variable_get(:@journals).kind_of?(Array))
    assert(@controller.instance_variable_get(:@journal_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_journals_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.journals({})
    assert(@controller.instance_variable_get(:@journals).kind_of?(Array))
    assert(@controller.instance_variable_get(:@journal_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_journals_with_user_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index, :user_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.journals({})
    assert(@controller.instance_variable_get(:@journals).kind_of?(Array))
    assert(@controller.instance_variable_get(:@journal_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_users
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.users({})
    assert(@controller.instance_variable_get(:@users).kind_of?(Array))
    assert(@controller.instance_variable_get(:@user_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_users_with_param
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.users({:page_size=> 2, :user_page=> 1, :require_avatar=>false, :require_description=>false})
    assert(@controller.instance_variable_get(:@users).kind_of?(Array))
    assert(@controller.instance_variable_get(:@user_pages).kind_of?(ActionController::Pagination::Paginator))
  end

  def test_users_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.users({})
    assert(@controller.instance_variable_get(:@users).kind_of?(Array))
    assert(@controller.instance_variable_get(:@user_pages).kind_of?(ActionController::Pagination::Paginator))
  end

end
