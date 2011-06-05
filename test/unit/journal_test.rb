#!ruby
#
# c 2006 makalumedia
# 
# Journal class model tests
# 
# 2006-11-16  james.anderson
# 

require File.dirname(__FILE__) + '/../test_helper'

# tests for
# - static retrieval functions
# - model structure
class JournalTest < Test::Unit::TestCase

  fixtures :users, :groups, :journals, :urlnames, :entries

  def test_find_journal_args()
    assert_raise(ArgumentError) {Journal.find_instance({})}
  end
  
  def test_should_find_journal_by_id
    assert Journal.find_instance("1")
    assert Journal.find_instance(:id=>"1")
    assert Journal.find_instance(:journal_id=>"1")
    assert_raise(Journal::NotFoundError) {Journal.find_instance(:id=>"", :if_does_not_exist=>:error)}
    assert_nil(Journal.find_instance(:id=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_journal_by_title
    assert Journal.find_instance(:title=>"a journal", :user=>nil)
    assert_raise(Journal::NotFoundError) {Journal.find_instance(:title=>"", :if_does_not_exist=>:error)}
    assert_nil(Journal.find_instance(:title=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_journal_by_urlname
    name = Journal.new().urlnameify("a journal")
    assert Journal.find_instance(:urlname=>name, :user=>nil)
    assert_raise(Journal::NotFoundError) {Journal.find_instance(:urlname=>"", :if_does_not_exist=>:error)}
    assert_nil(Journal.find_instance(:urlname=>"", :if_does_not_exist=>nil))
  end

  def test_should_find_journal_user
    assert journal = Journal.find_instance(:id=>"1")
    assert journal.owner(true);
  end
  
  def test_url_hash
    assert journal = Journal.find_instance(:id=>"1")
    assert_equal(journal.url_hash,
                 {:controller => 'journals', :user_id => journal.owner.id.to_s, :journal_id => "1"})
  end
  
  def test_words
    assert journal = Journal.find_instance(:id=>"1")
    # allow for the max on the first days == 1, 2
    assert_equal(24, journal.words())
  end
  
  def test_words_required
    assert journal = Journal.find_instance(:id=>"1")
    assert_equal((1..21).inject{|sum,i| sum + i}, journal.words_required())
  end
  
  # test with initial count of 3 (thus 2 = 3-1)
  def test_words_required_offset
    assert journal = Journal.find_instance(:id=>"2")
    assert_equal((3..23).inject{|sum,i| sum + i}, journal.words_required())
  end
  
  def test_completion_ratio
    assert journal = Journal.find_instance(:id=>"1")
    assert_equal(24.0/(1..21).inject{|sum,i| sum + i}, journal.completion_ratio)
  end
    
  def test_running_words_required
    assert journal = Journal.find_instance(:id=>"1")
    assert_equal((1..11).inject{|sum,i| sum + i}, journal.running_words_required())
  end
  
  # test with initial count of 3 (thus 2 = 3-1)
  def test_running_words_required_offset
    assert journal = Journal.find_instance(:id=>"2")
    assert_equal((3..13).inject{|sum,i| sum + i}, journal.running_words_required())
  end
  
  def test_running_completion_ratio
    assert journal = Journal.find_instance(:id=>"1")
    assert_equal(journal.running_completion_ratio, 24.0/(1..11).inject{|sum,i| sum + i})
  end
  
  def test_group_ids
    assert journal = Journal.find_instance(:id=>"1")
    assert_not_nil(journal.group_ids())
  end
  
  def test_count
    Journal.find(:all, :select=> 'SQL_CALC_FOUND_ROWS *',
                       :order => 'updated_at DESC')
    count = Journal.count_by_sql('SELECT FOUND_ROWS()')
    assert_equal(count, Journal.count)
  end

  def test_count_with_scope
    count = 0
    Journal.with_scope(:find=> {:conditions=> ['user_id = ?', "1"]}) {
      Journal.find(:all, :select=> 'SQL_CALC_FOUND_ROWS *',
                         :order => 'updated_at DESC')
      count = Journal.count_by_sql('SELECT FOUND_ROWS()')
    }
    assert_equal(count, Journal.find(:all, :select=> 'SQL_CALC_FOUND_ROWS *',
                                           :conditions=> ['user_id = ?', "1"]).length)
  end

  # the include causes it to ignore the :select
  def dont_test_count_with_include
    Journal.find(:all, :limit=> 2,
                       :include=> 'owner',
                       :conditions=> "avatar != ''",
                       :select=> 'SQL_CALC_FOUND_ROWS *',
                       :order => 'journals.updated_at DESC')
    count = Journal.count_by_sql('SELECT FOUND_ROWS()')
    assert_equal(count, Journal.find(:all, 
                       :include=> 'owner',
                       :conditions=> "avatar != ''",
                       :order => 'journals.updated_at DESC').length)
  end

  def test_count_with_limit
    list = Journal.find(:all, :limit => 2,
                       :offset=> 2,
                       :conditions =>[ "scope=?", User::SCOPE_PUBLIC ],
                       :select=> 'SQL_CALC_FOUND_ROWS *',
                       :order => 'updated_at DESC')
    count = Journal.count_by_sql('SELECT FOUND_ROWS()')
    assert_equal(2, list.length)
    assert_equal(count, Journal.find(:all, :conditions =>[ "scope=?", User::SCOPE_PUBLIC ],
                                            :order => 'updated_at DESC').length )
  end
  
  # test that membership and ownership has been erased
  # this requires re-retrieving after savnig
  def test_remove
    assert(user = User.find("1"))
    assert(journal = Journal.find(:first , :conditions=>'user_id = 1'))
    j_id = journal.id
    groups = journal.groups
    journal.remove!
    assert( (nil == (new_j = Journal.find(:first , :conditions=>'user_id = 1'))) ||
            (new_j.id != j_id) )
    assert(journal = Journal.find(j_id))
    assert(journal.removed?)
    assert(user = User.find("1"))
    assert_equal( false, user.journals.include?(journal))
    assert_equal( false, groups.any?{|g|
      g=Group.find(g.id)
      g.journals.include?(journal)})
  end
  
  def test_entry_sort
    j = Journal.find(1)
    assert_equal({}, j.entry_sort)
    j.entry_sort=({'column'=> 'created_at'})
    assert_equal({'column'=> 'created_at'}, j.entry_sort)
    j.entry_sort=(nil)
    assert_equal({}, j.entry_sort)
  end
end
