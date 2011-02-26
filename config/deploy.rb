require 'bundler/capistrano'
require 'yaml'
require 'pathname'

set :application, "blog"
set :repository,  "git://github.com/dalizard/blog.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :deploy_to, "/www-data/blog"
set :use_sudo, false

role :web, "calvin.forebits.com"                          # Your HTTP server, Apache/etc
role :app, "calvin.forebits.com"                          # This may be the same as your `Web` server
role :db,  "calvin.forebits.com", :primary => true # This is where Rails migrations will run
role :db,  "calvin.forebits.com"

set :sync_directories, ["public/system/images"]
set :sync_backups, 3
set :db_file, "mongoid.yml"
set :db_drop, '--drop' # drop database (rewrites everything)


namespace :deploy do
  desc "Restarting mod_rails with restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_path}/tmp/restart.txt"
  end

  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end
end


# Disable the built in disable command and setup some intelligence so we can have images.
after "deploy:update_code", "deploy:web:update_maintenance_page"
disable_path = "#{shared_path}/system/maintenance/"
namespace :deploy do
  namespace :web do
    desc "Disables the website by putting the maintenance files live."
    task :disable, :roles => :web do
      on_rollback { run "mv #{disable_path}index.html #{disable_path}index.disabled.html" }
      run "mv #{disable_path}index.disabled.html #{disable_path}index.html"
    end 
    desc "Enables the website by disabling the maintenance files."
    task :enable, :roles => :web do
        run "mv #{disable_path}index.html #{disable_path}index.disabled.html"
    end 
    desc "Copies your maintenance from public/maintenance to shared/system/maintenance."
    task :update, :roles => :web do
      run "rm -rf #{shared_path}/system/maintenance/; true"
      run "cp -r #{release_path}/public/maintenance #{shared_path}/system/"
    end
  end
end


# Based on http://gist.github.com/111597 http://gist.github.com/339471
#
# Capistrano sync.rb task for syncing databases and directories between the
# local development environment and production environment
# 
# Changes were made to sync MongoDB databases
# tested with mongoid
# Modified by Julius Pabrinkis

  namespace :sync do
 
    after "deploy:setup", "sync:setup"
 
    desc <<-DESC
      Creates the sync dir in shared path. The sync directory is used to keep
      backups of database dumps and archives from synced directories. This task will
      be called on 'deploy:setup'
      DESC
    task :setup do
      run "cd #{shared_path}; mkdir sync"
    end
 
    namespace :down do
 
      desc <<-DESC
        Syncs the database and declared directories from the selected 'production' environment
        to the local development environment. This task simply calls both the 'sync:down:db' and
        'sync:down:fs' tasks.
        DESC
      task :default do
        db and fs
      end
 
      desc <<-DESC
        Sync the production database to local
        DESC
      task :db, :roles => :db, :only => { :primary => true } do
        filename = "database.production.#{Time.now.strftime '%Y-%m-%d_%H-%M-%S'}.sql.bz2"
        on_rollback { delete "#{shared_path}/sync/#{filename}" }
        username, password, database, host = remote_database_config('production')
        production_database = database

        run "mongodump -db #{database}"
        run "tar -cjf #{shared_path}/sync/#{filename} dump/#{database}"
        run "rm -rf dump"
        purge_old_backups "database"
        
        download "#{shared_path}/sync/#{filename}", "tmp/#{filename}"
        
        username, password, database = database_config('development')
        system "tar -xjvf tmp/#{filename}"
        
        system "mongorestore #{fetch(:db_drop, '')} -db #{database} dump/#{production_database}"
        
        system "rm -f tmp/#{filename} | rm -rf dump"
        
        logger.important "sync database from the 'production' to local finished"
      end
 
      desc <<-DESC
        Sync the production files to local
        DESC
      task :fs, :roles => :web, :once => true do
 
        server, port = host_and_port
 
        Array(fetch(:sync_directories, [])).each do |syncdir|
          unless File.directory? "#{syncdir}"
            logger.info "create local '#{syncdir}' folder"
            Dir.mkdir "#{syncdir}"
          end
          logger.info "sync #{syncdir} from #{server}:#{port} to local"
          destination, base = Pathname.new(syncdir).split
          system "rsync --verbose --archive --compress --copy-links --delete --stats --rsh='ssh -p #{port}' #{user}@#{server}:#{current_path}/#{syncdir} #{destination.to_s}"
        end
 
        logger.important "sync filesystem from the 'production' to local finished"
      end
 
    end
 
    namespace :up do
 
      desc "Syncs the database and declared directories from the local development environment to the production environment. This task simply calls both the 'sync:up:db' and 'sync:up:fs' tasks."
      task :default do
        db and fs
      end
 
      desc <<-DESC
        Sync the local db to production
        DESC
      task :db, :roles => :db, :only => { :primary => true } do
        username, password, database = database_config('development')
        dev_database = database
        filename = "database.#{database}.#{Time.now.strftime '%Y-%m-%d_%H-%M-%S'}.tar.bz2"
        system "mongodump -db #{database}"
        system "tar -cjf #{filename} dump/#{database}"
        
        upload filename, "#{shared_path}/sync/#{filename}"
        
        system "rm -f #{filename} | rm -rf dump"
        
        username, password, database, host = remote_database_config('production')
        # extract to home dir
        run "tar -xjvf #{shared_path}/sync/#{filename}"
        # clean import
        run "mongorestore #{fetch(:db_drop, '')} -db #{database} dump/#{dev_database}"
        # remove extracted dump
        run "rm -rf dump"
        
        purge_old_backups "database"
        
        logger.important "sync database from local to the 'production' finished"
      end
 
      desc <<-DESC
        Sync the local files to production
        DESC
      task :fs, :roles => :web, :once => true do
 
        server, port = host_and_port
        Array(fetch(:sync_directories, [])).each do |syncdir|
          logger.info "The current dir is: #{syncdir}"
          destination, base = Pathname.new(syncdir).split
          if File.directory? "#{syncdir}"
            # Make a backup
            logger.info "backup #{syncdir}"
            run "tar cjf #{shared_path}/sync/#{base}.#{Time.now.strftime '%Y-%m-%d_%H:%M:%S'}.tar.bz2 #{current_path}/#{syncdir}"
            purge_old_backups "#{base}"
          else
            logger.info "Create '#{syncdir}' directory"
            run "mkdir #{current_path}/#{syncdir}"
          end
 
          # Sync directory up
          logger.info "sync #{syncdir} to #{server}:#{port} from local"
          system "rsync --verbose --archive --compress --keep-dirlinks --delete --stats --rsh='ssh -p #{port}' #{syncdir} #{user}@#{server}:#{current_path}/#{destination.to_s}"
        end
        logger.important "sync filesystem from local to the 'production' '#{'production'}' finished"
      end
 
    end
 
    #
    # Reads the database credentials from the local config/database.yml file
    # +db+ the name of the environment to get the credentials for
    # Returns username, password, database
    #
    def database_config(db)
      database = YAML::load_file("config/#{fetch(:db_file, 'database.yml')}")
      return database["#{db}"]['username'], database["#{db}"]['password'], database["#{db}"]['database'], database["#{db}"]['host']
    end

    
    #
    # Reads the database credentials from the remote config/database.yml file
    # +db+ the name of the environment to get the credentials for
    # Returns username, password, database
    #
    def remote_database_config(db)
      remote_config = capture("cat #{shared_path}/config/#{fetch(:db_file, 'database.yml')}")
      database = YAML::load(remote_config)
      return database["#{db}"]['username'], database["#{db}"]['password'], database["#{db}"]['database'], database["#{db}"]['host']
    end
 
    #
    # Returns the actual host name to sync and port
    #
    def host_and_port
      return roles[:web].servers.first.host, ssh_options[:port] || roles[:web].servers.first.port || 22
    end
 
    #
    # Purge old backups within the shared sync directory
    #
    def purge_old_backups(base)
      count = fetch(:sync_backups, 5).to_i
      backup_files = capture("ls -xt #{shared_path}/sync/#{base}*").split.reverse
      if count >= backup_files.length
        logger.important "no old backups to clean up"
      else
        logger.info "keeping #{count} of #{backup_files.length} sync backups"
        delete_backups = (backup_files - backup_files.last(count)).join(" ")
        try_sudo "rm -rf #{delete_backups}"
      end
    end
 
  end
