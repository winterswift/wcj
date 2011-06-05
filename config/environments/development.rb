#!ruby
#
# Word Count Journal environment
# Settings specified here will take precedence over those in config/environment.rb
#
# 2006-12-01  james.anderson  changed to require mail delivery to succeed.

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Enable the breakpoint server that script/breakpointer connects to
config.breakpoint_server = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false
config.action_view.cache_template_extensions         = false
config.action_view.debug_rjs                         = true

# not true: # Don't care if the mailer can't send
# 2006-21-01 changed to signal errors in  order to indicate success as part of
# sign-up
config.action_mailer.raise_delivery_errors = true
