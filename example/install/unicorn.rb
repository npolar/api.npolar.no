worker_processes 4
user 'api'

preload_app true
timeout 180

working_directory '/home/api/api.npolar.no' # git clone git@github.com:npolar/api.npolar.no.git
listen "0.0.0.0:9000", :backlog => 1024
# listen "api.npolar:80", :backlog => 1024
# listen "/tmp/api-npolar.sock", :backlog => 1024

pid '/home/api/api.pid'
stderr_path '/home/api/log/error.log'
stdout_path '/home/api/log/out.log'
