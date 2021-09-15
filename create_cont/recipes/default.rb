search(:classes, "uid:20w2081d").each do |result|
    ruby_block "check container #{result['cid']}-#{result['uid']}" do
        block do
            cont = `/snap/bin/lxc list --format json | jq '.[] | select(.name == \"#{result['cid']}-#{result['uid']}\") | {user:(.name),dist:.state.network.eth0.addresses[] | select(.family == \"inet\") | .address}'`
            #Chef::Log.info cont
            if cont == '' then
                p "no container"
            end
        end
        if `/snap/bin/lxc list --format json | jq '.[] | select(.name == \"#{result['cid']}-#{result['uid']}\") | {user:(.name),dist:.state.network.eth0.addresses[] | select(.family == \"inet\") | .address}'` == '' then
            notifies :run, "bash[create env #{result['cid']}-#{result['uid']}]", :immediately
        end
    end

    bash "create env #{result['cid']}-#{result['uid']}" do
        user 'vagrant'
        group 'lxd'
        cwd '/home/vagrant'
        action :nothing
        notifies :run, "bash[create device #{result['cid']}-#{result['uid']}]", :immediately
        code "/snap/bin/lxc launch chefserver:#{result['cid']} #{result['cid']}-#{result['uid']}"
    end

    bash "create device #{result['cid']}-#{result['uid']}" do
        user 'vagrant'
        group 'lxd'
        cwd '/home/vagrant'
        action :nothing
        code "/snap/bin/lxc config device add #{result['cid']}-#{result['uid']} http proxy listen=tcp:0.0.0.0:#{result['port']} connect=tcp:$(/snap/bin/lxc list --format json | jq -r '.[] | select(.name == \"#{result['uid']}\") | .state.network.eth0.addresses[] | select(.family == \"inet\") | .address'):80 bind=host"
    end
end
