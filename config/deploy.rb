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

# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end