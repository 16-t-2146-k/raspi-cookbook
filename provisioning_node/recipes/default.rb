#if (!node["create_cont"]["cwd"]) then
case node["platform"]
when "debian"
    node["create_cont"]["user"] = "pi"
    node["create_cont"]["cwd"] = "/home/pi"
when "ubuntu"
    node["create_cont"]["user"] = "ubuntu"
    node["create_cont"]["cwd"] = "/home/ubuntu"
end


apt_update 'Update the apt' do
    action :update
end

apt_package 'lxc' do
    action :install
    options '-y'
    not_if 'which lxc'
end

apt_package 'snapd' do
    action :install
    options '-y'
    not_if 'which snap'
end

apt_package 'jq' do
    action :install
    options '-y'
    not_if 'which jq'
end

directory "/tmp/chef" do
    mode   '0775'
    owner node["create_cont"]["user"]
    group node["create_cont"]["user"]
    action :create
    not_if { File.exist?("/tmp/chef") }
end

#git "/home/ubuntu/rasapp" do
#  repository "https://github.com/16-t-2146-k/rasapp.git"
#  revision "main"
#  user "ubuntu"
#  group "ubuntu"
#  action :sync
#end

directory '/home/ubuntu/rasapp/public/classes' do
    owner node["create_cont"]["user"]
    group node["create_cont"]["user"]
    mode '0755'
    action :create
end

directory '/home/ubuntu/rasapp/public/classes/contents' do
    owner node["create_cont"]["user"]
    group node["create_cont"]["user"]
    mode '0755'
    action :create
end

directory '/home/ubuntu/rasapp/public/classes/images' do
    owner node["create_cont"]["user"]
    group node["create_cont"]["user"]
    mode '0755'
    action :create
end

template "/tmp/chef/lxd_init.txt" do
    source "lxd_init.erb"
    action :create
end

#default profile以外を使用する場合
#template "/etc/netplan/70-eth1.yaml" do
#    source "70-eth1.erb"
#    action :create
#end

#template "/home/ubuntu/mydefault.yaml" do
#    source "mydefault.erb"
#    action :create
#end

#snapで入れる場合パス通さないとダメかも
bash 'snap install lxd' do
    user node["create_cont"]["user"]
    group 'root'
    action  :run
    cwd node["create_cont"]["cwd"]
    code "sudo snap install lxd"
    not_if { File.exist?("/snap/bin/lxd") }
    notifies :run, 'bash[lxd init]', :immediately
end

#userをlxdグループに入れないとroot以外は実行不可
bash "lxd init" do
    user node["create_cont"]["user"]
    group 'lxd'
    cwd node["create_cont"]["cwd"]
    action :nothing
    code "/snap/bin/lxd init < /tmp/chef/lxd_init.txt"
    notifies :run, 'bash[lxd remote add]', :immediately
end

bash "lxd remote add" do
    user node["create_cont"]["user"]
    group 'lxd'
    cwd node["create_cont"]["cwd"]
    action :nothing
    code "/snap/bin/lxc remote add chefserver https://chefserver:8443 --accept-certificate --password securitysecur"
    #notifies :run, 'bash[lxc profile edit default]', :immediately
end


#bash "lxc profile edit default" do
#    user 'ubuntu'
#    group 'lxd'
#    cwd '/home/ubuntu'
#    action :nothing
#    code "cat mydefault.yaml | /snap/bin/lxc profile edit default"
#end
