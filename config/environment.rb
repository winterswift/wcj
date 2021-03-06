#!ruby
#
# Word Count Journal environment settings
# 
# Be sure to restart your web server when you modify this file.
#
# 2006-11-21  james anderson  moved inits to here
# 2006-12-01  james.anderson  added smtp mailer settings
# 2006-12-03  james.anderson  wcj-bugs as exception target
# 
# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '1.1.6'

# bind the global file version repository ! before routes load
VERSIONS = {__FILE__ => "$Id: environment.rb 872 2007-04-10 16:59:14Z alex $"}

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  config.action_controller.session_store = :active_record_store

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector
end

# Include your application configuration below

# for feedtools-0.2.26
#
require "feed_tools"
FeedTools.configurations[:feed_cache] = "FeedTools::DatabaseFeedCache"

# require "annotation"
# require "annotation_grapher"

# try to initialize the application
# - mail origination settings
# - exception notification settings
#
begin
 begin
   site_hostname = ENV["HOSTNAME"] || Settings.http_host_name || IO.popen("hostname"){|io| io.read}
   site_file_name = site.hostname.rstrip.gsub('.', '_') + ".rb"
   site_file_pathname = (File.join(File.dirname(__FILE__), 'sites', site_file_name))
   begin
     load(site_file_pathname)
     ActiveRecord::Base.logger.warn("loaded: #{site_file_pathname}.")
   rescue Exception
     ActiveRecord::Base.logger.warn("cannot load: #{site_file_pathname}: #{$!.inspect}.")
   end
 rescue Exception
   ActiveRecord::Base.logger.warn("cannot determine site location: #{$!.inspect}.")
 end
   
 ActiveRecord::Base.logger.warn("WCJ: initial settings: #{Settings.all.inspect()}")
 ExceptionNotifier.exception_recipients = [ Settings.wcj_bugs_email ]
 ExceptionNotifier.email_prefix = "[WCJ ERROR] "
 case ENV["RAILS_ENV"]
 when 'production'
   ActionMailer::Base.server_settings = {
    :port  => 25, 
    :domain  => 'localhost' # ((Settings.wcj_host_label.blank? ? "" : (Settings.wcj_host_label + '.')) + Settings.wcj_http_domain),
    }
 else
   ActionMailer::Base.server_settings = {
    :address  => ('mail.' + Settings.wcj_mail_domain), # "mail.makalumedia.com",
    :port  => 25, 
    :domain  => ((Settings.wcj_host_label.blank? ? "" : (Settings.wcj_host_label + '.')) + Settings.wcj_http_domain),
    :user_name  => Settings.wcj_email,
    :password  => (Settings.wcj_email =~ /.*bug.*/ ? "B9pQwnSC" : "V8npNBm3"),
    :authentication  => :login
    }
    ActiveRecord::Base.logger.warn("ActionMailer::Base.server_settings: #{ActionMailer::Base.server_settings.inspect}.")
 end
 
rescue StandardError
 puts("could not init the application from Settings:\n#{$!}")
 puts($!.backtrace().join("\n"))
 ExceptionNotifier.exception_recipients = %w(wcj-bugs@makalumedia.com)
 ActionMailer::Base.server_settings = {
  :address  => "mail.makalumedia.com",
  :port  => 25, 
  :domain  => 'www.makalumedia.com',
  :user_name  => "wcj-bugs@makalumedia.com",
  :password  => "B9pQwnSC",
  :authentication  => :login
  }
end

# report on site-wide assertions

begin
 site_context = Annotation::Context.find("1")
 site_context.assertions.each{ |a|
   ActiveRecord::Base.logger.warn(a.to_s)
 }
 rescue Exception
   puts("could not print site context:\n#{$!}")
   puts($!.backtrace().join("\n"))
end

# nb. an attempt to segregate this into respective environment files failed: ala
# localhost:/Development/Source/dev/workspace/wordcountjournal/branches/functional-1 james$ script/server -e development
#=> Booting WEBrick...
#could not init the test environment from Settings:
#uninitialized constant Settings
#could not init the test environment from Settings:
#uninitialized constant Rails::Settings
#=> Rails application started on http://0.0.0.0:3000
#=> Ctrl-C to shutdown server; call with --help for options
#[2006-12-27 17:13:29] INFO  WEBrick 1.3.1
#[2006-12-27 17:13:29] INFO  ruby 1.8.5 (2006-08-25) [powerpc-darwin8.8.0]
#[2006-12-27 17:13:29] INFO  WEBrick::HTTPServer#start: pid=1527 port=3000


# setup timezones/utc handling

$INITIAL_UTC_OFFSET = Time.new.getlocal.utc_offset;
# ?? puts("old: #{ActiveRecord::Base.default_timezone}") == 'local'
ActiveRecord::Base.default_timezone = :utc # Store all times in the db in UTC
# first form, as in docs, did not work: the file was not found
# require 'tzinfo/lib/tzinfo' # Use tzinfo library to convert to and from the users timezone
require 'tzinfo' # Use tzinfo library to convert to and from the users timezone
ENV['TZ'] = 'UTC' # This makes Time.now return time in UTC

# correct paginator ignorance of the page parameter

module ActionController
  module Pagination
    def self.validate_options!(collection_id, options, in_action) #:nodoc:
      options.merge!(DEFAULT_OPTIONS) {|key, old, new| old}
      valid_options = DEFAULT_OPTIONS.keys
      valid_options << (options[:parameter] || DEFAULT_OPTIONS[:parameter]).to_sym
      valid_options << :actions unless in_action
      unknown_option_keys = options.keys - valid_options
      raise ActionController::ActionControllerError,
            "Unknown options: #{unknown_option_keys.join(', ')}" unless
              unknown_option_keys.empty?

      options[:singular_name] ||= Inflector.singularize(collection_id.to_s)
      options[:class_name]  ||= Inflector.camelize(options[:singular_name])
    end
    
    def paginator_and_collection_for(collection_id, options) #:nodoc:
      klass = options[:class_name].constantize
      key = options[:parameter] || DEFAULT_OPTIONS[:parameter]
      page  = (key ? (options[key.to_s] || options[key.to_sym]) : nil) || @params[options[:parameter]]
      count = count_collection_for_pagination(klass, options)
      paginator = Paginator.new(self, count, options[:per_page], page)
      collection = find_collection_for_pagination(klass, options, paginator)
      return paginator, collection
    end
    private :paginator_and_collection_for
  end

  class UrlRewriter
    
    def build_query_string_public(h)
      build_query_string(h)
    end
    
    private
    
    # generate a query string which encodes hash values as expected by the url parser
    # resolve atomic values as before, but walk hash values to the leaves and
    # then encode the tree path in the query key
    def build_query_string(hash, only_keys = nil, resolver = Routing)
      elements = []
      query_string = ""

      only_keys ||= hash.keys
      
      only_keys.each do |key|
        value = hash[key] 
        key = CGI.escape key.to_s
        if value.class == Array
          key <<  '[]'
        else
          value = [ value ]
        end
        value.each { |val|
          if val.kind_of?(Hash)
            elements << build_hash_query(val, [key], resolver)
          else
            elements << "#{key}=#{resolver.extract_parameter_value(val)}"
          end
        }
      end
      
      query_string << ("?" + elements.join("&")) unless elements.empty?
      query_string
    end
    
    def build_hash_query(hash, stack, resolver)
      
      elements = []
      
      hash.each_pair{|key, value|
        value_stack =  stack + [key]
        if (value.kind_of?(Hash))
          elements << build_hash_query(value, value_stack, resolver)
        else
          elements << "#{value_stack.first}#{value_stack[1..-1].map{|key| '[' + key.to_s + ']'}.join('')}=#{resolver.extract_parameter_value(value)}"
        end
      }
      elements.join("&")
    end
  end
end

# Patch the paginator
module ActionView::Helpers::PaginationHelper
  def pagination_links_each(paginator, options)
    options = DEFAULT_OPTIONS.merge(options)
    link_to_current_page = options[:link_to_current_page]
    always_show_anchors = options[:always_show_anchors]
  
    current_page = paginator.current_page
    window_pages = current_page.window(options[:window_size]).pages
    return if window_pages.length <= 1 unless link_to_current_page
    
    first, last = paginator.first, paginator.last
    
    html = ''
    if always_show_anchors and not (wp_first = window_pages[0]).first?
      html << yield(first.number)
      html << '<span class="break">...</span>' if wp_first.number - first.number > 1
      html << ' '
    end
      
    window_pages.each do |page|
      if current_page == page && !link_to_current_page
        html << page.number.to_s
      else
        html << yield(page.number)
      end
      html << ' '
    end
    
    if always_show_anchors and not (wp_last = window_pages[-1]).last? 
      html << '<span class="break">...</span>' if last.number - wp_last.number > 1
      html << yield(last.number)
    end
    
    html
  end
end