#!ruby
#
# c 2006 makalumedia
# 
# Group class model tests
# 
# 2006-11-16  james.anderson
# 

require File.dirname(__FILE__) + '/../test_helper'

# tests for
# - static retrieval functions
# - model structure
# 
class GroupTest < Test::Unit::TestCase

  fixtures :users, :groups, :journals, :urlnames

  def test_find_group_args()
    assert_raise(ArgumentError) {Group.find_instance({})}
  end
  
  def test_should_find_group_by_id
    assert Group.find_instance("1")
    assert Group.find_instance(:id=>"1")
    assert_raise(Group::NotFoundError) {Group.find_instance(:id=>"", :if_does_not_exist=>:error)}
    assert_nil(Group.find_instance(:id=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_group_by_title
    assert Group.find_instance(:title=>"a group", :user=>nil)
    assert_raise(Group::NotFoundError) {Group.find_instance(:title=>"", :if_does_not_exist=>:error)}
    assert_nil(Group.find_instance(:title=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_group_by_urlname
    name = Group.new().urlnameify("a group")
    assert Group.find_instance(:urlname=>name, :user=>nil)
    assert_raise(Group::NotFoundError) {Group.find_instance(:urlname=>"", :if_does_not_exist=>:error)}
    assert_nil(Group.find_instance(:urlname=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_group_user
    assert group = Group.find_instance(:id=>"1")
    assert group.owner(true);
  end
  
  def test_url_hash
    assert group = Group.find_instance(:id=>"1")
    assert_equal( group.url_hash,
                  {:controller => 'groups', :user_id => group.owner.id.to_s,
                   :group_id => "1"} )
  end

  def test_user_journal_groups
    assert_equal([Group.find(2)], Group.user_journal_groups(User.find(1), Journal.find(3)))
  end
end
