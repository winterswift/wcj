#
# unit test for PagesController exercises collection retrieval without request

require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end


class UsersControllerUnitTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :users, :groups_users, :roles_users, :entries
  
  def setup
    @controller = UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_session
    login_as "anauthor"
    assert_equal(ActionController::TestSession, @request.session.class)
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

  def test_journals
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
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

end
