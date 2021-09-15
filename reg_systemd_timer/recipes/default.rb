chef_client_systemd_timer "Run Chef Infra Client on #{node['name']}" do
  accept_chef_license      false
  chef_binary_path         `which chef-client |tr -d "\\n"`#"/opt/chef/bin/chef-client"
  config_directory         "/etc/chef"
  #cpu_quota                Integer, String
  daemon_options           ["-N #{node['name']}"]
  delay_after_boot         "1min"
  description              "Chef Infra Client periodic execution"
  interval                 "1seconds"
  job_name                 "chef-client"
  run_on_battery           true
  splay                    "1seconds"
  user                     "root"
  action                   :add
end