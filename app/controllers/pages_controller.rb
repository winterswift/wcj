#!ruby
#
# Word Count Journal index page controller
# 
# 2006-12-03 james.anderson  added required_*, and *_limit settings, params with defaults

VERSIONS[__FILE__] = "$Id: pages_controller.rb 879 2007-05-15 16:06:26Z alex $"

class Correspondence < User
  CREATE_ATTRIBUTE_NAMES = [:subject, :bug] + UsersController::CREATE_ATTRIBUTE_NAMES
  def subject
    @subject
  end
  def subject=(string)
    @subject = string
  end
  def name
    self.first_name
  end
  def bug
    @bug
  end
  def bug=(yes_or_no)
    @bug = yes_or_no
  end
 
  def validate_on_create()
    super()
    if (subject.blank?)
      errors.add("subject", "is empty.")
    end
    if (description.blank?)
      errors.add("description", "is empty")
    end
  end
end


class PagesController < ApplicationController
  CONTACT_SUCCESS_DESTINATION = :contact

  access_rule 'admin', :only => [:settings, :versions]

  #sidebar :featured_journal, :only => :index, :position => 'sidebar'
  #sidebar :explore, :only => :index
  
  # position = 'sidebar'.to_sym.to_s 
  # position = sidebar_setting(:pages, :site_about)
  # puts("position: #{position} = #{position == 'sidebar'}")
  #sidebar :site_words, :only => :index, :position => sidebar_setting(:pages, :site_words)
  sidebar :site_intro, :only => :index, :position => (sidebar_setting(:pages, :site_intro) || :sidebar)
  #sidebar :site_announcement, :only => :index, :if => :logged_in?, :position => sidebar_setting(:pages, :site_words)
  
  sidebar :account_login, :unless => :logged_in?, :only => :index, :position => 'sidebar'
  
  sidebar :site_about, :only => :index, :position => sidebar_setting(:pages, :site_about)
  sidebar :site_entries, :only => :index, :position => sidebar_setting(:pages, :site_entries)
  sidebar :site_comments, :only => :index, :position => sidebar_setting(:pages, :site_comments)
  sidebar :latest_entries, :only => :index, :position => sidebar_setting(:pages, :latest_entries, 'footer')
  sidebar :latest_photos, :only => :index, :position => sidebar_setting(:pages, :latest_photos, 'footer')
  sidebar :latest_comments, :only => :index, :position => sidebar_setting(:pages, :latest_comments, 'footer')
  #sidebar :people, :only => :index

  def index
    @user = find_user_if_specified!(params)
    # in general, the ApplicationController's methods compute collections
    @comments = nil;
    @groups = nil;
    @group_pages = nil;
    @entries = nil;
    @entry_pages = nil;
    @journals = nil;
    @journal_pages = nil;
    @users = nil;
    @user_pages = nil;
    @site_entries = nil;
    @site_comments = nil;
    # now fixed in _latest_photos to use the method
    @photos = nil;   
  end
  

   
  def about
    
  end
  
  def advertising
    
  end
  
  def privacy
  end

  def contact
    if request.post?
      @user = Correspondence.new(UsersController::filter_attributes(params[:user],
                                                                  Correspondence::CREATE_ATTRIBUTE_NAMES))

      @user.login = "ignorethis"
      @user.password = "ignorethis"
      @user.password_confirmation = "ignorethis"
      if (@user.valid?)
        begin
          UserNotifier.deliver_contact(User.new(:login=>"wcj",
                                                :email=>(case @user.bug
                                                         when true, 'true', 'yes', '1'
                                                           Settings.bugs_email
                                                         else
                                                           Settings.wcj_email
                                                         end)),
                                       @user)
          flash[:notice] = "Your message has been sent."
          # clear the description
          @user.description=("")
        rescue Exception
          flash[:error] = "Unable to send your message. Please try again later."
          logger.warn("contact: deliver_contact exception: #{$!}")
        end
        
        case CONTACT_SUCCESS_DESTINATION
        when :home
          if (logged_in?)
            redirect_to(:controller=> 'users', :action=> 'show', :user_id=> current_user.id)
          else
            redirect_to(:controller=> 'pages', :action=> 'index')
          end
        else
          # rerender with possibly replaced description
        end
      else
        # re-render the form
      end
    else
      # set-up to render the form
      @user = ( logged_in? ? Correspondence.new(:email=> current_user.email,
                                      :description=> "",
                                      :first_name=> current_user.name,
                                      :subject=> "",
                                      :bug=>0) :
                             Correspondence.new(:email=> "",
                                      :description=> "",
                                      :first_name=> "",
                                      :subject=>"",
                                      :bug=>0) )
      # puts("get: user: #{@user.inspect}")
    end
  end

  def tos
  end
  
  hide_action :breadcrumb_trail
  
  def breadcrumb_trail()
    trail = [ ['Home', home_url] ]
    case (action_name.instance_of?(String) ? action_name.intern() : action_name)
    when :about
      trail << 'About WCJ'
    when :tos
      trail << "Terms of service"
    when :privacy
      trail << 'Privacy policy'
    when :contact
      trail << 'Contact us'
    end
    trail
  end

end