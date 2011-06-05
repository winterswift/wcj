class CreateAdmin < ActiveRecord::Migration
  def self.up
    admin = User.create(:login=>User::ADMIN_LOGIN, :first_name=>"site", :last_name=>"admin",
                         :email=>"wcj@wordcountjournal.com",
                         :state=>"active",
                         :description=>"This is the initial site administrator",
                         :scope=>"private",
                         :password=>"nixnada",
                         :password_confirmation=>"nixnada")
    admin.roles << Role.find_by_title("admin")
    admin.roles << Role.find_by_title("user")
    if admin.save()
      puts("admin user: #{admin.inspect()}")
    else
      puts("admin user not saved: #{admin.inspect()}")
      puts("admin user not saved: #{admin.errors.full_messages()}")
    end
  end

  def self.down
    admin = User.find_by_login("wcj")
    if admin
      admin.destroy()
    else
      puts("cannot locate admin user.")
    end
  end
  
end
