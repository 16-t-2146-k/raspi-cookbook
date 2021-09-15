apt_update 'Update the apt' do
    action :update
end

apt_package 'lxc' do
    action :install
    options '-y'
    not_if 'which lxc'
end

bash 'snap install lxd' do
    user 'ubuntu'
    group 'root'
    action  :run
    cwd '/home/ubuntu'
    code "sudo snap install lxd"
    not_if { File.exist?("/snap/bin/lxd") }
    notifies :run, 'bash[lxd init]', :delayed
end

apt_package 'jq' do
    action :install
    options '-y'
    not_if 'which jq'
end

directory "/tmp/chef" do
    mode   '0775'
    owner 'ubuntu'
    group 'ubuntu'
    action :create
    not_if { File.exist?("/tmp/chef") }
end

template "/tmp/chef/lxd_init.txt" do
    source "lxd_init.erb"
    action :create
end

bash "lxd init" do
    user 'ubuntu'
    group 'lxd'
    cwd '/home/ubuntu'
    action :nothing
    code "/snap/bin/lxd init < /tmp/chef/lxd_init.txt"
    notifies :run, 'bash[lxd remote add]', :delayed
end

bash "lxd remote add" do
    user 'ubuntu'
    group 'lxd'
    cwd '/home/ubuntu'
    action :nothing
    code "/snap/bin/lxc remote add chefserver https://chefserver:8443 --accept-certificate --password securitysecur"
end
