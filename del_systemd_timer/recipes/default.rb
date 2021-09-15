chef_client_systemd_timer "Delete chefclient systemd timer on #{node['name']}" do
  job_name                 "chef-client"
  user                     "root"
  action                   :remove
end