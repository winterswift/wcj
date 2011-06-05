#
# unit test for PagesController exercises collection retrieval without request

require File.dirname(__FILE__) + '/../test_helper'
require 'application'

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end


class ApplicationControllerUnitTest < Test::Unit::TestCase
  fixtures :journals, :groups, :groups_journals, :users, :groups_users, :roles_users, :roles, :entries, :comments
  
  
  def setup
    @controller = ApplicationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.params=({})
    @controller.session=(@request.session)
    @bad_setting = {'column'=> 'title', 'order'=> 'asc'}
    @good_setting = {'column'=> 'date', 'order'=> 'desc'}
    @count = 0
    @setting_name = 'entry_sort'
  end

  def test_site_journal
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.site_journal()
    journal = @controller.instance_variable_get(:@site_journal)
    assert(journal.kind_of?(Journal))
    assert(journal.owner.is_admin?())
    assert_equal(Journal::SITE_JOURNAL_TITLE, journal.title)
  end

  def test_site_journal_as_guest
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.site_journal()
    journal = @controller.instance_variable_get(:@site_journal)
    assert(journal.kind_of?(Journal))
    assert(journal.owner.is_admin?())
    assert_equal(Journal::SITE_JOURNAL_TITLE, journal.title)
  end

  def test_site_entries
    login_as "anauthor"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.site_entries()
    entries = @controller.instance_variable_get(:@site_entries)
    journal = @controller.site_journal()
    assert(entries.kind_of?(Array))
    assert(entries.all?{|e| e.journal == journal})
  end


  def test_site_comments
    login_as "anadmin"
    @controller.params=({:action => :index})
    @controller.session=(@request.session)
    @controller.site_comments()
    comments = @controller.instance_variable_get(:@site_comments)
    journal = @controller.site_journal()
    assert(comments.kind_of?(Array))
    assert(comments.all?{|c| c.commentable.journal == journal})
  end
  
  def test_site_statistics
    assert(@controller.site_statistics().kind_of?(Hash))
    assert(@controller.site_statistics().equal?(@controller.site_statistics()))
  end
  
  def test_default_sort_order
    assert_equal({'column'=> '', 'order'=> ''}, @controller.page_sort_order())
  end
  
  
  # test presentation settings in various combinations
  # see http://wcj.trac.makalumedia.com/trac/wiki/SettingsAndDefaults
  
  # call arguments should supercede all other settings
  # but leave cache unchanged
  def test_setting_call_arguments
    @controller.params[@setting_name] = next_setting()
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => (setting1 = next_setting())}
    @controller.session['Journal/1'] = {@setting_name => (setting2 = next_setting())}
    journal = Journal.find(1)
    author = journal.owner
    user = User.find(3)
    author.assert(Journal, @setting_name, next_setting())
    author.assert(journal, @setting_name, next_setting())
    user.assert(Journal, @setting_name, next_setting())
    user.assert(journal, @setting_name, next_setting())
    @controller.site_context().deny(Journal, @setting_name)
    
    assert_equal(@good_setting,
                 @controller.presentation_setting(journal, @setting_name,
                                                  [{@setting_name=> @good_setting},
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()]))
    assert_equal(setting1,
                 (@controller.session['Journal'] || {})[@setting_name])
    assert_equal(setting2,
                 (@controller.session['Journal/1'] || {})[@setting_name])
  end
  
  # the settings in a request should be applied and cached both for the
  # requested resource and for its type
  def test_setting_request_current
    @controller.params['entry_sort'] = @good_setting
    @controller.session['entry_sort'] = @bad_setting
    @controller.session['Journal'] = {'entry_sort' => @bad_setting}
    @controller.session['Journal/1'] = {'entry_sort' => @bad_setting}
    author = User.find(1)
    user = User.find(3)
    author.assert(Journal, @setting_name, @bad_setting)
    author.assert(Journal.find(1), @setting_name, @bad_setting)
    user.assert(Journal, @setting_name, @bad_setting)
    user.assert(Journal.find(1), @setting_name, @bad_setting)
    @controller.site_context().deny(Journal, @setting_name)
    
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()]))
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})['entry_sort'])
    assert_equal(@good_setting,
                 (@controller.session['Journal/1'] || {})['entry_sort'])
  end
  
  # if neither the arguments, nor the request specify a setting,
  # the values from previous request for the same resource should apply 
  def test_setting_request_past_specific_new
    @controller.params['entry_sort'] = @good_setting
    @controller.session['entry_sort'] = @bad_setting
    @controller.session['Journal'] = {'entry_sort' => @bad_setting}
    @controller.session['Journal/1'] = {'entry_sort' => @bad_setting}
    author = User.find(1)
    user = User.find(3)
    author.assert(Journal, @setting_name, @bad_setting)
    author.assert(Journal.find(1), @setting_name, @bad_setting)
    user.assert(Journal, @setting_name, @bad_setting)
    user.assert(Journal.find(1), @setting_name, @bad_setting)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect a previous request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    
    # now a current request
    @controller.params['entry_sort'] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()]))
                 
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})['entry_sort'])
    assert_equal(@good_setting,
                 (@controller.session['Journal/1'] || {})['entry_sort'])
  end
  
  # if neither the arguments, nor the request specify a setting,
  # the values from previous request for the same resource should apply
  # this even if an intervening request for another resource was different 
  def test_setting_request_past_specific_old
    @controller.params['entry_sort'] = @good_setting
    @controller.session['entry_sort'] = @bad_setting
    @controller.session['Journal'] = {'entry_sort' => @bad_setting}
    @controller.session['Journal/1'] = {'entry_sort' => @bad_setting}
    author = User.find(1)
    user = User.find(3)
    author.assert(Journal, @setting_name, @bad_setting)
    author.assert(Journal.find(1), @setting_name, @bad_setting)
    user.assert(Journal, @setting_name, @bad_setting)
    user.assert(Journal.find(1), @setting_name, @bad_setting)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # then another previous request, but for a different resource
    # with different settings
    @controller.params['entry_sort'] = @bad_setting
    @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(2),
                                                   @controller.site_context()])
    
    
    # now a current request, without settings
    @controller.params['entry_sort'] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()]))
    # the general setting is from the intervening request
    assert_equal(@bad_setting,
                 (@controller.session['Journal'] || {})['entry_sort'])
    # while the specific setting is from the initial request
    assert_equal(@good_setting,
                 (@controller.session['Journal/1'] || {})['entry_sort'])
    # and the specific setting form the intervening request remains as well
    assert_equal(@bad_setting,
                 (@controller.session['Journal/2'] || {})['entry_sort'])
  end
  
  # a value from an initial request for one journal should apply to a later
  # request for another journal, as long as neither a specific nor a general
  # owner setting is present
  def test_setting_request_past_general
    @controller.params[@setting_name] = @good_setting
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => next_setting()}
    @controller.session['Journal/1'] = {@setting_name => next_setting()}
    author = User.find(1)
    user = User.find(3)
    author.deny(Journal, @setting_name)
    author.deny(Journal.find(1), @setting_name)
    user.deny(Journal, @setting_name)
    user.deny(Journal.find(1), @setting_name)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params[@setting_name] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(2),
                                                   @controller.site_context()]))
    # the general setting is from the initial request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting is also from the initial request
    assert_equal(@good_setting,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # ther is no specific setting from the second request
    assert_equal(nil,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  # a value specified by a reader for a specific journal applies when the
  # request has no setting, whether or not a request for another journal
  # had a setting
  def test_setting_default_reader_specific
    @controller.params['entry_sort'] = (setting1 = next_setting())
    @controller.session['entry_sort'] = next_setting()
    @controller.session['Journal'] = {'entry_sort' => next_setting()}
    @controller.session['Journal/1'] = {'entry_sort' => next_setting()}
    author = User.find(1)
    user = User.find(3)
    author.deny(Journal, @setting_name)
    author.deny(Journal.find(1), @setting_name)
    user.assert(Journal, @setting_name, next_setting())
    user.assert(Journal.find(1), @setting_name, next_setting())
    user.assert(Journal.find(2), @setting_name, @good_setting)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params['entry_sort'] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(2),
                                                   @controller.site_context()]))
    # the general setting is generalized from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting is also from the initial request
    assert_equal(setting1,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # the specific setting is from the user's assertions about the resource
    # from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  # a value specified by a reader profile for general journal applies when the
  # request has no setting, whether or not a request for another journal
  # had a setting
  def test_setting_default_reader_general
    @controller.params[@setting_name] = (setting1 = next_setting())
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => next_setting()}
    @controller.session['Journal/1'] = {@setting_name => next_setting()}
    author = User.find(1)
    user = User.find(3)
    author.deny(Journal, @setting_name)
    author.deny(Journal.find(1), @setting_name)
    user.assert(Journal, @setting_name, @good_setting)
    user.assert(Journal.find(1), @setting_name, next_setting())
    user.deny(Journal.find(2), @setting_name)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params['entry_sort'] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(2),
                                                   @controller.site_context()]))
    # the general setting was cached from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting is also from the initial request
    assert_equal(setting1,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # the is no specific setting from the second request
    assert_equal(nil,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  # settings asserted by the specific resource precede generalizations
  # and author's defaults
  def test_setting_resource
    @controller.params[@setting_name] = nil
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => next_setting()}
    @controller.session['Journal/1'] = {@setting_name => (setting1 = next_setting())}
    author = User.find(1)
    user = User.find(3)
    journal = Journal.find(2)
    # this assertion takes precedence
    journal.assert(journal, @setting_name, @good_setting)
    author.assert(Journal, @setting_name, next_setting())
    author.assert(Journal.find(2), @setting_name, next_setting())
    user.assert(Journal, @setting_name, next_setting())
    user.assert(Journal.find(1), @setting_name, next_setting())
    user.deny(Journal.find(2), @setting_name)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params[@setting_name] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(2),
                                                   @controller.site_context()]))
    # the general setting is changed by the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting is also from the initial request
    assert_equal(setting1,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # the specific setting remains from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  def test_setting_default_author_specific
    @controller.params[@setting_name] = (setting1 = next_setting())
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => next_setting()}
    @controller.session['Journal/1'] = {@setting_name => next_setting()}
    journal = Journal.find(2)
    author = journal.owner
    user = User.find(3)
    author.deny(Journal, @setting_name)
    author.assert(Journal.find(1), @setting_name, next_setting())
    author.assert(journal, @setting_name, @good_setting)
    user.deny(Journal, @setting_name)
    user.deny(Journal.find(1), @setting_name)
    user.deny(journal, @setting_name)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params[@setting_name] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   journal,
                                                   author,
                                                   @controller.site_context()]))
    # the general setting is cached from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting remains from the initial request
    assert_equal(setting1,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # the specific setting is also cached from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  def test_setting_default_author_general
    @controller.params[@setting_name] = (setting1 = next_setting())
    @controller.session[@setting_name] = next_setting()
    @controller.session['Journal'] = {@setting_name => next_setting()}
    @controller.session['Journal/1'] = {@setting_name => next_setting()}
    journal = Journal.find(2)
    author = journal.owner
    user = User.find(3)
    author.assert(Journal, @setting_name, @good_setting)
    author.assert(Journal.find(1), @setting_name, next_setting())
    author.deny(journal, @setting_name)
    user.deny(Journal, @setting_name)
    user.deny(Journal.find(1), @setting_name)
    user.deny(journal, @setting_name)
    @controller.site_context().deny(Journal, @setting_name)
    
    # effect an initial request
    @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()])
    # now a current request, for a different resource, without settings
    @controller.params[@setting_name] = nil
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(2), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   journal,
                                                   author,
                                                   @controller.site_context()]))
    # the general setting is cached from the second request
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
    # the specific setting remains from the initial request
    assert_equal(setting1,
                 (@controller.session['Journal/1'] || {})[@setting_name])
    # there is no specific setting from the second request
    assert_equal(nil,
                 (@controller.session['Journal/2'] || {})[@setting_name])
  end
  
  def test_setting_site
    @controller.params[@setting_name] = nil
    @controller.session[@setting_name] = nil
    @controller.session['Journal'] = nil
    @controller.session['Journal/1'] = nil
    author = User.find(1)
    user = User.find(3)
    journal = Journal.find(2)
    # this assertion is the last resort
    author.deny(Journal, @setting_name)
    author.deny(Journal.find(1), @setting_name)
    user.deny(Journal, @setting_name)
    user.deny(Journal.find(1), @setting_name)
    @controller.site_context().assert(Journal, @setting_name, @good_setting)
 
    # the default should apply
    assert_equal(@good_setting,
                 @controller.presentation_setting(Journal.find(1), @setting_name,
                                                  [nil,
                                                   @controller.session,
                                                   user,
                                                   Journal.find(1),
                                                   @controller.site_context()]))
    # and is cached
    assert_equal(@good_setting,
                 (@controller.session['Journal'] || {})[@setting_name])
  end
  
  def test_intern_param
    assert_equal(908, @controller.intern_param_value("0908", 1))
  end
  protected
  
  def next_setting()
    @count += 1;
    {"order"=>"desc", "column"=>"nonexistent", :count=> @count}
  end
end
