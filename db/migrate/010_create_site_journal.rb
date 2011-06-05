class CreateSiteJournal < ActiveRecord::Migration
  def self.up
    if (admin = User.find_by_login(User::ADMIN_LOGIN))
      puts("creating journal for admin user: #{admin.inspect()}")
      create_site_journal(admin)
    else
      puts("admin user not found!")
    end
  end

  def self.down
    site_journal = Journal.find(:first, :include => [:owner],
                                        :conditions=> [ 'journals.title = ? AND users.login = ?',
                                                       Journal::SITE_JOURNAL_TITLE,
                                                       User::ADMIN_LOGIN ])
    if site_journal
      site_journal.destroy()
    else
      puts("cannot locate site_journal.")
    end
  end
  
  
  def self.create_site_journal(admin)
    site_journal = Journal.new(:title=> Journal::SITE_JOURNAL_TITLE,
                               :scope=> User::SCOPE_PUBLIC,
                               :comment_state=> 'draft',
                               :description=> "This is a record of things to do on the site, user's wishes, suggestions, and the general state-of-affairs.",
                               :start_date=> Date.today, :end_date=> Date.today.+(999),
                               :created_at=> Time.now.utc(),
                               :created_by=> admin.id, :updated_by=> admin.id)
    site_journal.owner = admin
    if site_journal.save()
      puts("site journal: #{site_journal.inspect()}")
    else
      puts("journal not saved: #{site_journal.inspect()}")
      puts("journal not saved: #{site_journal.errors.full_messages()}")
    end
  end
end
