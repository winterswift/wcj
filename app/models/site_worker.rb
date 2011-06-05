#!ruby
#
# Word Count Journal controller for site activities
# 

VERSIONS[__FILE__] = "$Id: site_controller.rb 572 2007-01-12 16:23:39Z james $"

class SiteWorker
  OVERDUE_NOTIFY = :overdue_notify;
  
  def setup_work(args={})
    @users_processed = 0
    @users_total = User.count
    @cycle_time = args[:cycle_time] || (60 * 60) # one hour
    @tasks = args[:tasks] || {}
    ActiveRecord::Base.logger.info("SiteWorker#setup_work: #{self}: [#{@tasks.join(',')}]")
    self
  end
  
  def start_working()
    ActiveRecord::Base.logger.info("SiteWorker#start_working #{self}: [#{@tasks.join(',')}]")
    @tasks.each{|task|
      ActiveRecord::Base.logger.info("task #{task}:")
      case task
      when OVERDUE_NOTIFY
        @start_time = Time.now
        @users_reminders = 0
        ActiveRecord::Base.logger.info("task #{task}: x #{@users_total} users")
        @users_total.times{|i|
          user = User.find(i+1)
          if (user.active?)
            @users_processed += 1;
            if ((deadline = user.overdue_reminders) &&
                (@start_time > deadline))
              @users_reminders += 1
              # process the reminders and reset the time
              ActiveRecord::Base.logger.info("task #{task}: User#overdue_reminder: #{user}")
              user.overdue_reminder()
              user.overdue_reminders=(true)
            end
          end
        }
        ActiveRecord::Base.logger.info("task #{task}: x #{@users_reminders} users reminders / #{@users_processed} users processed.")
      end
    }
  end
    
  def results()
  end
  
  def progress()
    @users_processed / @users_total
  end
  
end
