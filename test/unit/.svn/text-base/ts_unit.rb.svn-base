#!/usr/bin/env ruby
#

[
 "entry_test",
 "role_test",
 "user_test",
 "journal_test",
 "group_test",
 "annotation_test",
 
 
 "application_controller_test",
 "entries_controller_test",
 "groups_controller_test",
 "journals_controller_test",
 "pages_controller_test",
 "users_controller_test"].map {|filename|
  pathname = File.join(File.dirname(__FILE__), filename) + ".rb"
  begin
    load(pathname)
  rescue Exception
    puts("Error loading test: #{pathname}: #{$!}")
  end
  }
