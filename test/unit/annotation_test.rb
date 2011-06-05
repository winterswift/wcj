#!ruby
#
# Word Count Journal tests for annotations
# (c) 2006 makalumedia
# 

require File.dirname(__FILE__) + '/../test_helper'


class AnnotationTest < Test::Unit::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  # 
  include AuthenticatedTestHelper
  fixtures :users, :groups, :journals, :entries
   
  def test_annotator_should_create
    user = create_user
    assert_nil(user.annotation_context())
    assert(user.current_annotation_context.kind_of?(Annotation::Context))
  end
  
  def test_favorites
    user = User.find(1)
    journal = Journal.find(5)
    assert(!(user.public_favorite_journals.include?(journal)))
    assert(user.add_favorite(journal, User::SCOPE_PUBLIC))
    # find again to refresh favorites
    journal = Journal.find(5)
    assert(user.public_favorite_journals.include?(journal))
    assert(user.remove_favorite(journal))
    assert(!(user.public_favorite_journals.include?(journal)))
  end
    
  def test_subscribe_entry
    user = User.find(1)
    entry = Entry.find(1)
    
    user.subscribe(entry)
    assert(entry.subscribed_users().include?(user))
    assert(user.subscribed_entries().include?(entry))
    assert(user.subscriptions().include?(entry))
    user.unsubscribe(entry)
    assert(!(entry.subscribed_users().include?(user)))
    assert(!(user.subscribed_entries().include?(entry)))
  end
  
  def test_subscribe_journal
    user = User.find(1)
    journal = Journal.find(1)
    user.subscribe(journal)
    assert(journal.subscribed_users().include?(user))
    assert(user.subscribed_journals().include?(journal))
    assert(user.subscriptions().include?(journal))
    user.unsubscribe(journal)
    assert(!(journal.subscribed_users().include?(user)))
    assert(!(user.subscribed_journals().include?(journal)))
  end

  def test_read_time
    user = User.find(1)
    journal = Journal.find(1)
    time = Time.now
    user.set_read_time(journal, time)
    time += 1
    user.set_read_time(journal, time)
    assert_equal(time, user.asserted(journal, :read_time))
  end
  
  def test_sort_order_old
   j_old = Journal.find(1)
   entry_sort = {:order=> 'desc'}
   j_old.entry_sort=(entry_sort)
   
   assert_equal(Journal.find(1).entry_sort(), {:order=> 'desc'})
  end
  
  def test_sort_order_new
   end_date = 20.days.from_now
   start_date = 10.days.from_now
   j_new = Journal.new({:title=> "test journal", :user_id=>3,
                    :scope=> User::SCOPE_PUBLIC,
                    :description=> "to test journal sort order",
                    :start_date=> start_date.to_s,
                    :end_date=> end_date.to_s})
   entry_sort = {:order=> 'desc'}
   j_new.entry_sort=(entry_sort)
   j_new.save!
   
   j_old = Journal.find(j_new.id)
   assert(j_old.annotation_context)
   assert_equal(j_old.id, j_old.annotation_context.annotator_id)
   assert_equal(j_old.entry_sort, entry_sort)   
  end
  
  protected
    def create_user(options = {})
      User.create({ :login => 'annewauthor', :email => 'annewauthor@example.com',
                    :scope=> User::SCOPE_PUBLIC,
                    :description=> "",
                    :password => 'test', :password_confirmation => 'test' }.merge(options))
    end
end
