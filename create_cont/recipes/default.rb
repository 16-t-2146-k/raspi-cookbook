server_data = data_bag_item('server', node[:hostname])

search(:classes, "uid:#{node[:hostname]}").each do |result|

    ruby_block "set port #{result['cid']}-#{result['uid']} databag items" do
        block do
            if result['port'].empty? then
                _port = server_data['port'].shift
                server_data['used_port'].push(_port)
                result['port'] = _port

                _ip = server_data['ip'].shift
                server_data['used_ip'].push(_ip)
                result['ip'] = _port                

                databag_item = Chef::DataBagItem.new
                databag_item.data_bag('classes')
                databag_item.raw_data = {
                    'id' => result['id'],
                    'uid' => result['uid'],
                    'cid' => result['cid'],
                    'ip' => result['ip'],
                    'port' => result['port'],
                }
                databag_item.save

            end
        end
        notifies :run, "ruby_block[set #{server_data['hostname']} databag items]", :delayed
    end

    ruby_block "check container #{result['cid']}-#{result['uid']}" do
        block do
            cont = `/snap/bin/lxc list --format json | jq '.[] | select(.name == \"#{result['cid']}-#{result['uid']}\") | {user:(.name),dist:.state.network.eth0.addresses[] | select(.family == \"inet\") | .address}'`
            #Chef::Log.info cont
            if cont == '' then
                p "no container"
            end
        end
        if `/snap/bin/lxc list --format json | jq '.[] | select(.name == \"#{result['cid']}-#{result['uid']}\") | {user:(.name),dist:.state.network.eth0.addresses[] | select(.family == \"inet\") | .address}'` == '' then
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
        notifies :run, "bash[lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1]", :immediately
        code "/snap/bin/lxc config device add #{result['cid']}-#{result['uid']} http proxy listen=tcp:0.0.0.0:#{result['port']} connect=tcp:#{result['ip']}:80 bind=host"
    end

    bash "lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        notifies :run, "bash[lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address #{result['ip']}]", :immediately
        code "/snap/bin/lxc network attach lxdbr0 #{result['cid']}-#{result['uid']} eth1"
    end

    bash "lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address #{result['ip']}" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        notifies :run, "bash[lxc start #{result['cid']}-#{result['uid']}]", :immediately
        code "/snap/bin/lxc config device set #{result['cid']}-#{result['uid']} eth1 ipv4.address #{result['ip']}"
    end

    bash "lxc start #{result['cid']}-#{result['uid']}" do
        user 'ubuntu'
        group 'lxd'
        cwd '/home/ubuntu'
        action :nothing
        code "/snap/bin/lxc start #{result['cid']}-#{result['uid']}"
    end

    file "/home/ubuntu/rasapp/public/classes/contents/#{result['cid']}.json" do
        content "{\"ip\":#{result['ip']},\"port\":\"#{result['port']}\"}"
        mode '0755'
        owner 'ubuntu'
        group 'ubuntu'
        action :create
    end

    remote_file "/home/ubuntu/rasapp/public/classes/images/#{result['cid']}.png" do
        source "file:///home/vagrant/images/#{result['cid']}.png"
        owner 'ubuntu'
        group 'ubuntu'
        mode '0755'
        action :create
    end
end

ruby_block "set #{server_data['hostname']} databag items" do
    block do
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('server')
        databag_item.raw_data = {
            'id' => server_data['id'],
            'hostname' => server_data['hostname'],
            'ip' => server_data['ip'],
            'used_ip' => server_data['used_ip'],
            'port' => server_data['port'],
            'used_port' => server_data['used_port'],
        }
        databag_item.save
    end
    action :nothing
end