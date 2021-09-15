apt_update 'Update the apt' do
    action :update
end

apt_package 'lxc' do
    action :install
    options '-y'
    not_if 'which lxc'
end

bash 'snap install lxd' do
    user 'vagrant'
    group 'root'
    action  :run
    cwd '/home/vagrant'
    code "sudo snap install lxd"
    not_if { File.exist?("/snap/bin/lxd") }
end

apt_package 'jq' do
    action :install
    options '-y'
    not_if 'which jq'
end

directory "/tmp/chef" do
    mode   '0775'
    owner 'vagrant'
    group 'vagrant'
    action :create
    not_if { File.exist?("/tmp/chef") }
end

template "/tmp/chef/lxd_init.txt" do
    source "lxd_init.erb"
    action :create
end

bash "lxd init" do
    user 'vagrant'
    group 'lxd'
    cwd '/home/vagrant'
    not_if { File.exist?("/var/snap/lxd/common/lxd/storage-pools/default") }
    code "/snap/bin/lxd init < /tmp/chef/lxd_init.txt"
end
