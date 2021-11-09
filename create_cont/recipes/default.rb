server_data = data_bag_item('server', node[:hostname])
classes_data = search(:classes, "uid:#{node[:hostname]}")
#nodeで動いているコンテナ(stateは無関係)
launched_cont = []
#databagに記載のあるコンテナ
list_cont = []
#databagに記載のないコンテナ
unlist_cont = []

ruby_block "check unlist container" do
    block do
        `/snap/bin/lxc list -c n -f csv`.each_line{|line|
            launched_cont.push(line.chomp)
        }
        classes_data.each do |result|
            list_cont.push(result['id'])
        end
        unlist_cont = launched_cont - list_cont
        Chef::Log.info "launched_cont #{launched_cont}"
        Chef::Log.info "list_cont #{list_cont}"
        Chef::Log.info "unlist_cont #{unlist_cont}"
    end
    action :run
end

#search(:classes, "uid:#{node[:hostname]}").each do |result|
classes_data.each do |result|

    #空きポートをportに設定(databagの作成,更新)
    if result['port'] == '' then
        _port = server_data['port'].shift
        server_data['used_port'].push(_port)
        result['port'] = _port
        Chef::Log.info "#{result['cid']}-#{result['uid']} will use #{_port} port"

        #_ip = server_data['ip'].shift
        #server_data['used_ip'].push(_ip)
        #result['ip'] = _ip        
        #p _ip

        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('classes')
        databag_item.raw_data = {
            'id' => result['id'],
            'uid' => result['uid'],
            'cid' => result['cid'],
            #'ip' => result['ip'],
            'port' => result['port'],
        }
        databag_item.save
    end

    ruby_block "check container #{result['cid']}-#{result['uid']}" do
        block do
            #cont = `/snap/bin/lxc list #{result['cid']}-#{result['uid']} -c n -f csv`
            #Chef::Log.info cont
            #if cont == '' then
            if list_cont.include? "#{result['cid']}-#{result['uid']}" then
                p "no container"
            end
        end
        #if `/snap/bin/lxc list #{result['cid']}-#{result['uid']} -c n -f csv` == '' then
        if list_cont.include? "#{result['cid']}-#{result['uid']}" then
            notifies :run, "bash[lxc init #{result['cid']}-#{result['uid']}]", :immediately
        end
    end

    bash "lxc init #{result['cid']}-#{result['uid']}" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        notifies :run, "bash[lxc config device add #{result['cid']}-#{result['uid']} http proxy]", :immediately
        code "/snap/bin/lxc init chefserver:#{result['cid']} #{result['cid']}-#{result['uid']}"
    end

    bash "lxc config device add #{result['cid']}-#{result['uid']} http proxy" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        notifies :run, "bash[lxc start #{result['cid']}-#{result['uid']}]", :immediately
        #notifies :run, "bash[lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1]", :immediately
        code lazy {"/snap/bin/lxc config device add #{result['cid']}-#{result['uid']} http proxy listen=tcp:0.0.0.0:#{result['port']} connect=tcp:127.0.0.1:80 bind=host"}
    end

#ipの固定をする場合に使用．lxdの設定のip_range内でip指定して．
#    bash "lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1" do
#        user 'ubuntu'
#        group 'lxd'
#        cwd '/home/ubuntu'
#        action :nothing
#        notifies :run, "bash[lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address]", :immediately
#        code "/snap/bin/lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1"
#    end

#    bash "lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address" do
#        user 'ubuntu'
#        group 'lxd'
#        cwd '/home/ubuntu'
#        action :nothing
#        notifies :run, "bash[lxc start #{result['cid']}-#{result['uid']}]", :immediately
#        code lazy{"/snap/bin/lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address #{result['ip']}"}
#    end

    bash "lxc start #{result['cid']}-#{result['uid']}" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        code "/snap/bin/lxc start #{result['cid']}-#{result['uid']}"
    end

    file "/home/ubuntu/rasapp/public/classes/contents/#{result['cid']}.json" do
        content lazy{"{\"ip\":\"\",\"port\":\"#{result['port']}\"}"}
        mode '0755'
        owner 'ubuntu'
        group 'ubuntu'
        action :create
    end

    cookbook_file "/home/ubuntu/rasapp/public/classes/images/#{result['cid']}.png" do
        source "#{result['cid']}.png"
        owner 'ubuntu'
        group 'ubuntu'
        mode '0755'
        action :create
    end
end

#server databagの更新
ruby_block "set #{server_data['hostname']} databag items" do
    block do
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('server')
        databag_item.raw_data = {
            'id' => server_data['id'],
            'hostname' => server_data['hostname'],
            #'ip' => server_data['ip'],
            #'used_ip' => server_data['used_ip'],
            'port' => server_data['port'],
            'used_port' => server_data['used_port'],
        }
        databag_item.save
    end
    action :run
end