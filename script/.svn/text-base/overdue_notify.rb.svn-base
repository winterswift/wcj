#!/usr/bin/env ruby

ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'production'
puts("#{__FILE__} in mode #{ENV['RAILS_ENV']}")

require File.dirname(__FILE__) + '/../config/boot'
require 'optparse'
ActiveRecord::Base.logger= Logger.new("#{RAILS_ROOT}/log/#{File.basename(__FILE__)}-#{Time.now.strftime('%Y%m%dT%H%M%S')}Z.log")
ActiveRecord::Base.logger.level = Logger::INFO
ActionMailer::Base.logger= ActiveRecord::Base.logger

load "#{RAILS_ROOT}/config/environment.rb"

def timestamp()
  "#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}Z"
end

ActiveRecord::Base.logger.info("#{timestamp()}: Starting Overdue Notify task.")
SiteWorker.new().setup_work(:tasks=> [SiteWorker::OVERDUE_NOTIFY]).start_working
ActiveRecord::Base.logger.info("#{timestamp()}: Overdue Notify task completed.")
