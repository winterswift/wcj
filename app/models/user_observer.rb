class UserObserver < ActiveRecord::Observer

  def after_create(user)
    if Settings.require_activation()
      UserNotifier.deliver_signup(user)
    else
      begin
        UserNotifier.deliver_signup(user)
      rescue Exception
        # delegate to the user instance to get logging.
        # ActiveRecord::Observer doesn't bind a logger
        user.logger.warn("after_create: deliver_signup exception: #{$!}")
      end
    end
  end
  
end
