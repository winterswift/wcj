#!/usr/bin/env ruby
#
# remove all users excep a select set of users
#
# this is intended to be loaded in to a console session and executed manually

require File.dirname(__FILE__) + '/../config/boot'

TO_RETAIN =
[ [1, "wcj"],
  [49,"Sara"],
  [242,"FantasyNovelist"],
  [27,"FictionScribe"],
  [44,"Awriter"],
  [136,"Lemmie Splayne"],
  [169,"genboy"],
  [114,"junitha"],
  [103,"purefuel99"],
  [31,"mccomas"],
  [64,"sam"],
  [2,"mr. anderson"],
  [3,"cheese"],
  [4,"katmandan"],
  [5,"mhenders"],
  [17,"alex"],
  [18,"murphtron"] ]


def timestamp()
  "#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}Z"
end

def message(message)
  ActiveRecord::Base.logger.info(message)
  puts(message)
end

def prune_users()
  message("#{timestamp()}: Pruning task started.")

  User.find(:all).each{|u|
    if (u.removed?)
      message("#{u.url} already removed.")
    elsif (TO_RETAIN.assoc(u.id))
      message("#{u.url} retained.")
    else
      message("#{u.url} to remove...")
      case
      when u.is_admin?
        message("will  not remove admin: #{u.login}.")
      else
        u.remove!()
        message("#{u.url} removed.")
      end
    end
  }

  TO_RETAIN.each{|pair|
    id = pair[0]
    login = pair [1]
    
    begin
      u = User.find(id)
      if (login == u.login)
        message("#{u.url} confirmed.")
      else
        message("#{u.url} login mismatch: #{login} != #{u.login}.")
      end
    rescue Exception
      message("[#{id}, #{login}] missing.")
    end
  }
  
  message("#{timestamp()}: Pruning task completed.")
end



