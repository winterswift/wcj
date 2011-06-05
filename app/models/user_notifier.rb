#!ruby
#
# Word Count Journal controller for uesrs
# 
# 2006-12-01  james.anderson  alternative signup notification

unless Settings.bound?(:comment_from_commentor)
  Settings.comment_from_commentor = true;
end

class UserNotifier < ActionMailer::Base

  def activation(user)
    setup_email(user)
    @subject    += 'Your account has been activated!'
    @body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
  end

  def change_password(user, actor)
    setup_email(user)
    body[:actor] = actor
    @subject += 'Your password has been changed!'
  end

  def change_password_failed(user, actor)
    setup_email(user)
    body[:actor] = actor
    @subject += 'An attempt was made to change your password!'
  end
  
  def comment(user, commentor, entry, comment_text)
    setup_email(user)
    if ( commentor )
      case Settings.user_notifier_comment_source
      when 'user'
        @from = commentor.email
        @headers["sender"] = user.email
      when 'site'
      else
        logger.warn("invalid comment source: #{Settings.user_notifier_comment_source}")
      end
      @headers["reply-to"] = commentor.email
      # don't set this: @headers["return-path"] = commentor.email
    end
    body[:commentor] = commentor
    body[:comment_text] = comment_text
    body[:entry] = entry
    @subject += "Someone has left a comment about '#{entry.journal.title}'."
  end
  
  def contact(user, correspondence)
    setup_email(user)
    @subject += ("[contact] " + correspondence.subject)
    case Settings.user_notifier_contact_source
    when 'user'
      @from = correspondence.email
      @headers["sender"] = user.email
    when 'site'
    else
      logger.warn("invalid comment source: #{Settings.user_notifier_comment_source}")
    end
    # overwrite the reply-to with the correspondent's address
    @headers["reply-to"] = correspondence.email
    # rfc2822 is clear, that this should not be here
    # @headers["return-path"] = correspondence.email
    @body[:reply_to] = correspondence.email
    @body[:name] = correspondence.name
    @body[:description] = correspondence.description
  end

  def entry_subscriber_notice(user, journal, entry, controller)
    setup_email(user)
    @subject += "New comments for journal '#{journal.title}'"
    body[:journal] = journal
    body[:entry] = entry
    body[:entry_url] = controller.url_for({:only_path=> false}.merge(entry.url_hash()))
    body[:user_profile_url] = controller.url_for({:only_path=> false}.merge(user.url_hash()))
    body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
  end
 
  def group_email_invitation(group, member, authentication)
    setup_email(member)
    body[:group] = group
    body[:owner] = group.owner
    body[:authentication] = authentication
    @subject += "You have been invited to join '#{group.title}'"
  end

  def group_invitation_reminder(group, member, user)
    setup_email(user)
    body[:group] = group
    body[:member] = member
    @subject += "#{member.login ? member.login : member.email} has been invited to join '#{group.title}'"
  end

  def group_user_invitation(group, member, authentication)
    setup_email(member)
    body[:group] = group
    body[:authentication] = authentication
    @subject += "You have been invited to join '#{group.title}'"
  end

  def journal_subscriber_notice(user, journal, entry, controller)
    setup_email(user)
    @subject += "New entries for journal '#{@journal.title}'"
    body[:journal] = journal
    body[:entry] = entry
    body[:entry_url] = controller.url_for({:only_path=> false}.merge(entry.url_hash()))
    body[:user_profile_url] = controller.url_for({:only_path=> false}.merge(user.url_hash()))
    body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
  end

  def user_overdue_reminder(user, journals)
    # would be nice to have a controller for the url generation, but
    # first need to figure out how to make one for a batch job
    setup_email(user)
    root_url = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
    @subject += 'It is time to write in your Word Count Journal - write away!'
    @body[:journals] = journals.map{|j| [j, "#{root_url}#{j.url}"]}
    @body[:url]  = root_url
    @body[:user_profile_url] = "#{root_url}#{user.url}"
  end
 
  def reactivation(user)
    setup_email(user)
    @subject += 'Your account has been reactivated!'
  end
  
  def recover_password(user)
    setup_email(user)
    @subject    += 'Your new password is enclosed'
    @body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
    @body[:password]  = user.recovery_password
  end

  def settings_update(user)
    if (user.kind_of?(User))
      setup_email(user)
      @subject    += 'Settings Modification'
      @body[:settings]  = Settings.all
      @body[:user]  = user
    else
      logger.warn("invalid user: #{user.inspect}.")
    end
  end
  
  def signup(user)
    setup_email(user)
    if Settings.require_activation
      @subject    += 'Please activate your Word Count Journal account'
      @body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}/account/activate/#{user.activation_code}"
    else
      @subject    += 'Welcome to Word Count Journal!'
      # @body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}/users/#{user.id}"
      @body[:url]  = "http://#{(Settings.wcj_host_label.blank? ? '' : (Settings.wcj_host_label + '.'))}#{Settings.wcj_http_domain}"
    end
  end

  def suspension(user)
    setup_email(user)
    @subject += 'Your account has been suspended!'
  end

  protected
  def setup_email(user)
    @recipients  = "#{user.email}"
    @headers["reply-to"] = "no-reply@wordcountjournal.com"
    @from        =  Settings.wcj_email || "mail@wordcountjournal.com"
    @subject     = "[WCJ] "
    @sent_on     = Time.now.utc
    @body[:user] = user
  end
end
