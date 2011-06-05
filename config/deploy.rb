
set :keep_releases, 5
set :user,          'www-data'
set :deploy_via,    :export
set :scm,           :subversion
set :rails_env,     'production'
set :use_sudo,      false

# comment out if it gives you trouble. newest net/ssh needs this set.
ssh_options[:paranoid] = false
ssh_options[:forward_agent] = true

# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.
#
# We define separate tasks for each environment within which the roles and other
# environment specific variables are defined and run that task first to set up 
# the environment for execution of a task   e.g.  cap production deploy

task :production do
  role :web, 'www.wordcountjournal.com'
  role :app, 'www.wordcountjournal.com'
  role :db, 'www.wordcountjournal.com', :primary => true
  set :monit_group,   'wcj_mongrel'
  set :repository,    "svn+ssh://#{ENV['USER']}@svn.makalumedia.com/repos/wcj/branches/production"
  set :deploy_to,     "/w/wordcountjournal.com"
end

task :stage do
  role :web, 'stage.wordcountjournal.com'
  role :app, 'stage.wordcountjournal.com'
  role :db, 'stage.wordcountjournal.com', :primary => true
  set :monit_group,   'stage_wcj_mongrel'
  set :repository,    "svn+ssh://#{ENV['USER']}@svn.makalumedia.com/repos/wcj/trunk"
  set :deploy_to,     "/w/stage.wordcountjournal.com"
end


# =============================================================================
# TASKS
# Don't change unless you know what you are doing!
after "deploy", "deploy:cleanup"
after "deploy:migrations", "deploy:cleanup"
after "deploy:update_code","deploy:symlink_configs"
after "deploy:update_code","deploy:symlink_assets"

# =============================================================================  
namespace :mongrel do
  desc <<-DESC
  Start Mongrel processes on the app server.
  DESC
  task :start, :roles => :app do
    sudo "/usr/sbin/monit start all -g #{monit_group}"
  end
  
  desc <<-DESC
  Restart the Mongrel processes on the app server.
  DESC
  task :restart, :roles => :app do
    sudo "/usr/sbin/monit restart all -g #{monit_group}"
  end

  desc <<-DESC
  Stop the Mongrel processes on the app server.
  DESC
  task :stop, :roles => :app do
    sudo "/usr/sbin/monit stop all -g #{monit_group}"
  end
end

# =============================================================================
namespace :apache do 
  desc "Start apache on the web server."
  task :start, :roles => :web do
    sudo "/etc/init.d/apache2 start"
  end

  desc "Restart the apache processes on the web server by starting and stopping the cluster."
  task :restart , :roles => :web do
    sudo "/etc/init.d/apache2 restart"
  end

  desc "Stop the apache processes on the web server."
  task :stop , :roles => :web do
    sudo "/etc/init.d/apache2 stop"
  end
end

# =============================================================================
namespace(:deploy) do  
  task :symlink_configs, :roles => :app, :except => {:no_symlink => true} do
    run <<-CMD
      cd #{release_path} &&
      ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml &&
      ln -nfs #{shared_path}/config/mongrel_cluster.yml #{release_path}/config/mongrel_cluster.yml &&
      ln -nfs #{shared_path}/config/environments/production.rb #{release_path}/config/environments/production.rb
    CMD
  end
  
  task :symlink_assets, :roles => :app, :except => {:no_symlink => true} do
    # remove tmp before symlinking it as standard :finalize_update task creates it
    run <<-CMD
      cd #{release_path} &&
      rm -fr #{release_path}/tmp &&
      ln -nfs #{shared_path}/tmp #{release_path}/tmp &&
      ln -nfs #{shared_path}/old_logs #{release_path}/old_logs &&
      ln -nfs #{shared_path}/images #{release_path}/images
    CMD
  end
  
  task :rake_tasks, :roles => :app do
    run "cd #{release_path} && rake RAILS_ENV=#{rails_env} tmp:cache:clear public:cache:clear theme:cache:update"
  end
    
  desc "Long deploy will throw up the maintenance.html page and run migrations 
        then it restarts and enables the site again."
  task :long do
    transaction do
      update_code
      web.disable
      symlink
      migrate
    end
  
    restart
    web.enable
  end

  task :stop do
    web.disable
  end

  desc "Restart the Mongrel processes on the app server."
    
  task :restart, :roles => :app do
    mongrel.restart
  end
  
  desc "Start the Mongrel processes on the app server."
  task :spinner, :roles => :app do
    mongrel.start
  end

  desc "Tail the Rails production log for this environment"
  task :tail_production_logs, :roles => :app do
    run "tail -f #{shared_path}/log/production.log" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:host]}: #{data}" 
      break if stream == :err    
    end
  end
end
