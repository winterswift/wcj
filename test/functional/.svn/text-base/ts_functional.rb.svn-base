#!/usr/bin/env ruby
#
# add the relative ./functional directory to the search path
# $:.unshift File.join(File.dirname(__FILE__), "functional") 
["account_controller_test",
 "entries_controller_test",
 "groups_controller_test",
 "images_controller_test",
 "journals_controller_test",
 "pages_controller_test",
 "roles_controller_test",
 "site_controller_test",
 "spell_controller_test",
 "users_controller_test"].map {|filename|
  pathname = File.join(File.dirname(__FILE__), filename) + ".rb"
  begin
    load(pathname)
  rescue Exception
    puts("Error loading test: #{pathname}: #{$!}")
  end
  }


