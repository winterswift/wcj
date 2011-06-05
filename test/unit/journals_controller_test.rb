#
# unit test for PagesController exercises collection retrieval without request

require File.dirname(__FILE__) + '/../test_helper'
require 'journals_controller'

# Re-raise errors caught by the controller.
class JournalsController; def rescue_action(e) raise e end; end


class JournalsControllerUnitTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :users, :groups_users, :roles_users, :entries
  
  def setup
    @controller = JournalsController.new
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
    @controller.params=({:action => :index, :user_id=>'1', :journal_id=>'1',
                         'entry_sort'=> {'column'=> 'created_at', 'order'=> 'asc'}})
    @controller.session=(@request.session)
    @controller.instance_variable_set(:@user, User.find('1'))
    @controller.instance_variable_set(:@journal, Journal.find('1'))
    @controller.entries({:page_size=> 2, :entry_page=> 1, :require_photo=> true})
    # puts(@controller.session.inspect)
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
    # nb value are coerced to symbols
    assert_equal({'column'=> :created_at, 'order'=> :asc}, @controller.page_sort_order())
  end

  def test_entries_as_admin
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.entries({})
    assert(@controller.instance_variable_get(:@entries).kind_of?(Array))
    assert(@controller.instance_variable_get(:@entry_pages).kind_of?(ActionController::Pagination::Paginator))
  end
  
  # test the date handling for new journals
  def test_new
    login_as "anauthor"
    @controller.params=({:action => :index, :user_id=>'1'})
    user = User.find('1')
    @controller.instance_variable_set(:@user, user)
    ["UTC", "America/New_York", "America/Chicago",
     "America/Los_Angeles", "Asia/Tokyo", "Europe/Berlin"].map{|designator|
      user.timezone=(TZInfo::Timezone.get(designator))
      zone = user.timezone;
      @controller.new()
      journal = @controller.instance_variable_get(:@journal)
      # puts("new journal: user: #{user.id}@#{user.timezone} journal: [#{zone.utc_to_local(journal.start_date)}=#{journal.start_date}(UTC) - #{zone.utc_to_local(journal.end_date)}=#{journal.end_date}(UTC)]")                                                    
    }
  end

end
