#!ruby
#
# c 2006 makalumedia
# 
# Group class model tests
# 
# 2006-11-16  james.anderson
# 2006-11-26  james.anderson  completion factor (adresses #15)

require File.dirname(__FILE__) + '/../test_helper'

class EntryTest < Test::Unit::TestCase
  fixtures :entries, :journals

  # Replace this with your real tests.
  def test_entry_completion_above()
    e = Entry.find(1)
    # puts("entry(#{e.id}): #{e.inspect()} words: #{e.words()}/#{e.words_required()}/#{e.completion_ratio()} #{e.completion_ratio() > 1.0}")
    assert e.completion_ratio() > 1.0 
  end
  
  def test_entry_completion_ok
    e = Entry.find(3)
    # puts("entry(#{e.id}): #{e.inspect()} words: #{e.words()}/#{e.words_required()}/#{e.completion_ratio()} #{e.completion_ratio() > 1.0}")
    assert e.completion_ratio() == 1.0 
  end
  
  def test_entry_completion_below
    assert Entry.find(5).completion_ratio() < 1.0 
  end
  
  def test_url_hash
    assert(e = Entry.find(1))
    assert_equal( e.url_hash,
                  {:controller => 'entries', :user_id => e.user.id.to_s,
                   :journal_id => e.journal.id.to_s,
                   :year => e.date.strftime("%Y"), :month => e.date.strftime("%m"),
                   :date => e.date.strftime("%d")} )
  end
  
  def test_words
    assert_equal(0, Entry::words(""))
    assert_equal(0, Entry::words(" "))
    assert_equal(0, Entry::words(". "))
    assert_equal(0, Entry::words(" ."))
    assert_equal(0, Entry::words(" . "))
    assert_equal(1, Entry::words("a "))
    assert_equal(1, Entry::words(" a"))
    assert_equal(1, Entry::words(" a "))
    assert_equal(1, Entry::words("a. "))
    assert_equal(1, Entry::words("a ."))
    assert_equal(1, Entry::words(" a.a"))
    assert_equal(1, Entry::words(" a-a"))
    assert_equal(2, Entry::words(" a;a"))
    assert_equal(2, Entry::words(" a-a. a"))
    assert_equal(3, Entry::words("a a_a. a"))
    assert_equal(3, Entry::words("a s a"))
    assert_equal(3, Entry::words("a,s,a"))
    assert_equal(1, Entry::words(" asd's "))
  end
  
  def test_previous_entry()
    assert(Entry.find(1))
    assert_nil(Entry.find(1).previous_entry)
    assert(Entry.find(2))
    assert_equal(Entry.find(1), Entry.find(2).previous_entry)
    assert_equal(Entry.find(4), Entry.find(5).previous_entry)
  end
  
  def test_next_entry()
    assert(Entry.find(1))
    assert_equal(Entry.find(2), Entry.find(1).next_entry)
    assert(Entry.find(4))
    assert(Entry.find(5), Entry.find(4).next_entry)
    assert_nil(Entry.find(9).next_entry)
  end
  
  def test_adjacent_entry_unpublished()
    assert(Entry.find(16))
    assert_equal(Entry.find(17), Entry.find(16).next_entry(nil))
    assert_equal(Entry.find(18), Entry.find(16).next_entry())
    assert(Entry.find(18))
    assert_equal(Entry.find(17), Entry.find(18).previous_entry(nil))
    assert_equal(Entry.find(16), Entry.find(18).previous_entry())
  end
  

end
