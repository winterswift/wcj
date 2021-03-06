#
# unit test for PagesController exercises collection retrieval without request

require File.dirname(__FILE__) + '/../test_helper'
require 'entries_controller'

# Re-raise errors caught by the controller.
class EntriesController; def rescue_action(e) raise e end; end


class EntriesControllerUnitTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :users, :groups_users, :roles_users, :entries
  
  def setup
    @controller = EntriesController.new
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

  def test_entries_with_user_with_journal
    login_as "anauthor"
    @controller.params=({:action => :index, :user_id=> '1', :journal_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.instance_variable_set(:@journal, Journal.find('1'))
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

  def test_entries_with_user_with_journal_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index, :user_id=> '1', :journal_id=> '1'})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.instance_variable_set(:@journal, Journal.find('1'))
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end


end
