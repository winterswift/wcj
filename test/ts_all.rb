#!/usr/bin/env ruby
#

puts("#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}Z: running #{__FILE__}")
["unit/ts_unit",
 "functional/ts_functional"].map {|filename|
  pathname = File.join(File.dirname(__FILE__), filename) + ".rb"
  begin
    load(pathname)
  rescue Exception
    puts("Error loading test: #{pathname}: #{$!}")
  end
  }
