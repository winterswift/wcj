class AddSettingsTable < ActiveRecord::Migration
  def self.up
    create_table :settings, :force => true do |t|
        t.column :var, :string, :null => false
        t.column :value, :string, :null => true
        t.column :created_at, :datetime
        t.column :updated_at, :datetime
    end
   
   self.initialize_settings
  end

  def self.down
    drop_table :settings
  end
  
  def self.initialize_settings()
  # collection sizes
   Settings.rss_per_page = 30;
   Settings.html_per_page = 20;
   
   Settings.entry_sort = {'column'=> 'date', 'order'=> 'DESC'}
   
   # general
   Settings.comment_limit = 5;
   Settings.comment_sort_oder = 'desc'
   Settings.entry_limit = 5;
   Settings.entry_sort_oder = 'desc'
   Settings.group_limit = 5;
   Settings.group_sort_oder = 'desc'
   Settings.journal_limit = 5;
   Settings.journal_sort_oder = 'desc'
   Settings.photo_limit = 8;
   Settings.user_limit = 5;
   Settings.user_sort_oder = 'desc'
   # specific presentation contexts
   Settings.latest_entries_count = 5;
   Settings.latest_groups_count = 5;
   Settings.latest_journals_count = 5;
   Settings.latest_users_count = 8;
   Settings.list_entries_count = 7;
   Settings.list_groups_count = 8;
   Settings.list_journals_count = 10;
   Settings.list_users_count = 6;
   
   # site behaviour
   Settings.require_activation = false;  # require user activation on sign-up
   Settings.notify_entry_subscribers = true;
   Settings.notify_journal_subscribers = true;
   Settings.page_title = "Word Count Journal";
   Settings.user_notifier_comment_source = 'site';
   Settings.user_notifier_contact_source = 'user';

   # site location
   Settings.wcj_host_label = "wcj"  # see http://en.wikipedia.org/wiki/Hostname
   Settings.host_label = Settings.wcj_host_label
   Settings.wcj_http_domain = "makalumedia.com";
   Settings.http_domain = Settings.wcj_http_domain
   Settings.http_host_name = (Settings.wcj_host_label.blank? ? "" : (Settings.wcj_host_label + '.')) + Settings.wcj_http_domain
   Settings.wcj_mail_domain = "wordcountjournal.com";
   Settings.support_mail_domain = "makalumedia.com";
   # Settings.wcj_email = "wcj@wordcountjournal.com";
   Settings.wcj_email = "mail@" + Settings.wcj_mail_domain;
   # nb. this is the internal bugs destination - for exceptions &co
   Settings.wcj_bugs_email = "wcj-bugs@" + Settings.wcj_mail_domain;
   # nb. this is the external bugs destination - for contacts
   Settings.bugs_email = "bugs@" + Settings.wcj_mail_domain;
   Settings.exception_bugs_email = Settings.bugs_email;

   # interface settings
   Settings.format_time_format = "%Y-%m-%dT%H:%M:%S";
   Settings.format_date_format = "%d.%m.%Y";
   Settings.sidebars = {:accounts=> {},
                        :entries=> {},
                        :groups=> {},
                        :journals=> {},
                        :pages=>{ :site_about => nil, :site_entries=> nil, :site_comments=> nil},
                        :users=> {}}
   
   # Journal settings
   Settings.permit_retroactive_start_date = true;
   Settings.permit_retroactive_end_date = false;
   Settings.journal_duration_maximum = 730;
   
   end
end
