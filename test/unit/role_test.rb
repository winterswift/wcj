#!ruby
#
# Word Count Journal controller for accounts
# (c) 2006 makalumedia
# 

require File.dirname(__FILE__) + '/../test_helper'

class RoleTest < Test::Unit::TestCase
  fixtures :roles

  # Replace this with your real tests.
  def test_WCJ_SC_F01
    assert Role.find_by_title("guest")
    assert Role.find_by_title("user")
    assert Role.find_by_title("admin")
    assert_equal(Role.count(), 3)
  end
end
