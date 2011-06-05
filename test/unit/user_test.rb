#!ruby
#
# Word Count Journal controller for accounts
# (c) 2006 makalumedia
# 

require File.dirname(__FILE__) + '/../test_helper'

class UserTest < Test::Unit::TestCase
  # Be sure to include AuthenticatedTestHelper in test/test_helper.rb instead.
  # Then, you can remove it from this and the functional test.
  include AuthenticatedTestHelper
  fixtures :users, :roles_users

  def test_should_create_user
    assert_difference User, :count do
      user = create_user
      assert !user.new_record?, "#{user.errors.full_messages.to_sentence}"
    end
  end

  def test_should_create_user_with_duplicate_email
    assert_difference User, :count do
      user = create_user(:email => "anauthor@example.com")
      assert !user.new_record?, "#{user.errors.full_messages.to_sentence}"
    end
  end

  def test_should_require_unique_login
    assert_no_difference User, :count do
      user = create_user(:login => "anauthor")
      assert user.errors.on(:login)
    end
  end

  def test_should_require_login
    assert_no_difference User, :count do
      u = create_user(:login => nil)
      assert u.errors.on(:login)
    end
  end

  def test_should_require_password
    assert_no_difference User, :count do
      u = create_user(:password => nil)
      assert u.errors.on(:password)
    end
  end

  def test_should_require_password_confirmation
    assert_no_difference User, :count do
      u = create_user(:password_confirmation => nil)
      assert u.errors.on(:password_confirmation)
    end
  end

  def test_should_require_email
    assert_no_difference User, :count do
      u = create_user(:email => nil)
      assert u.errors.on(:email)
    end
  end

  def test_should_strip_description
    u = create_user(:description=>"text <tag> with html</tag>.")
    assert_equal(u.description, "text  with html.")
  end

  def test_should_reset_password
    users(:anauthor).update_attributes(:password => 'new password', :password_confirmation => 'new password')
    assert_equal users(:anauthor), User.authenticate('anauthor', 'new password')
  end

  def test_should_not_rehash_password
    users(:anauthor).update_attributes(:login => 'anauthor2')
    assert_equal users(:anauthor), User.authenticate('anauthor2', 'test')
  end

  def test_should_authenticate_user
    assert_equal users(:anauthor), User.authenticate('anauthor', 'test')
  end

  def test_should_set_remember_token
    users(:anauthor).remember_me
    assert_not_nil users(:anauthor).remember_token
    assert_not_nil users(:anauthor).remember_token_expires_at
  end

  def test_should_unset_remember_token
    users(:anauthor).remember_me
    assert_not_nil users(:anauthor).remember_token
    users(:anauthor).forget_me
    assert_nil users(:anauthor).remember_token
  end

  def test_find_user_args()
    assert_raise(ArgumentError) {User.find_instance(nil)}
    assert_raise(ArgumentError) {User.find_instance({})}
  end
  
  def test_should_find_user_by_id
    assert User.find_instance("1")
    assert User.find_instance(:id=>"1")
    assert User.find_instance(:user_id=>"1")
    assert_raise(User::NotFoundError) {User.find_instance(:id=>"", :if_does_not_exist=>:error)}
    assert_nil(User.find_instance(:id=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_user_by_name
    assert User.find_instance(:first_name=>"an", :last_name=>"author")
    assert_raise(User::NotFoundError) {User.find_instance(:last_name=>"", :if_does_not_exist=>:error)}
    assert_nil(User.find_instance(:last_name=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_user_by_login
    assert User.find_instance(:login=>"anauthor")
    assert_raise(User::NotFoundError) {User.find_instance(:login=>"", :if_does_not_exist=>:error)}
    assert_nil(User.find_instance(:login=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_user_journals
    assert user = User.find_instance(:id=>"1")
    assert journals = user.journals(true);
    assert journals.length() >= 2;
    assert !(journals.any?{|j| j.owner != user})
  end

  def test_url_hash
    assert user = User.find_instance(:id=>"1")
    assert_equal(user.url_hash, {:user_id=> "1", :controller=> 'users'})
  end
  
  def test_remove
    assert(user = User.find("1"))
    assert(journal = Journal.find(:first , :conditions=>'user_id = 1'))
    assert(group = Group.find(:first , :conditions=>'user_id = 1'))
    assert(comments = Comment.find_comments_by_user(user))
    user.annotation_context()
    assert(contexts = user.annotation_contexts())
    user.remove!
    assert(user = User.find("1"))
    assert(user.removed?)
    assert_equal( false, user.journals.any?{|j|
      if (j.active?)
        puts("still active: #{j}")
        true
      elsif (j.groups.length > 0)
        puts("still in groups: #{j.groups.join(',')}")
        true
      elsif (j.entries.length > 0)
        puts("journal #{j.id} still contains entries: #{j.entries.map{|i| i.id}.join(',')}")
        true
      end
    })
    assert_equal( [], user.entries)
    assert_equal( false, user.groups.any?{|g| (g.active? || g.journals.length > 0)})
    assert_equal( [], Comment.find(:all, :conditions => ["user_id = ?", user.id]))
    assert_equal( [], user.annotation_contexts())
  end
  
  def test_journal_unread
    j = Journal.find(1)
    u = User.find(1)
    u.set_read_time(j, j.updated_at - 600)
    assert_equal(j.updated_at - 600, u.journal_unread?(j))
    u.set_read_time(j, j.updated_at + 100)
    assert_equal(false, u.journal_unread?(j))
  end
  
  def dont_test_compute_next_deadline
    u = create_user()
    last_offset = 0;
    TzinfoTimezone.all.each{|zone|
      unless (last_offset == zone.utc_offset)
        u.instance_variable_set(:@timezone, nil)
        u.time_zone = nil;
        puts("zone: #{zone}")
        begin
          u.time_zone = zone.name
          last_offset = zone.utc_offset
          deadline = u.compute_next_deadline()
          unless ( u.compute_next_deadline(deadline+(60*60)) == (deadline + (60 * 60 * 24)) )
            puts("failed: #{zone} : #{deadline} ... #{u.compute_next_deadline(deadline+(60*60))}")
          end
        rescue Exception
          puts("can't use: #{zone}")
        end
      end
    }
  end
  
  protected
    def create_user(options = {})
      User.create({ :login => 'anewauthor', :email => 'anewauthor@example.com',
                    :scope=> User::SCOPE_PUBLIC,
                    :description=> "",
                    :password => 'test', :password_confirmation => 'test' }.merge(options))
    end
end
