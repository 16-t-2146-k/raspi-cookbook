#CWD = `echo ${HOME}`
#Chef::Log.info "cwd #{CWD}"
recipe = self

#if (!node["create_cont"]["cwd"]) then
case node["platform"]
when "debian"
    node.default["create_cont"]["user"] = "pi"
    node.default["create_cont"]["cwd"] = "/home/pi"
    node.default["create_cont"]["arch"] = "aarch64"
when "ubuntu"
    node.default["create_cont"]["user"] = "vagrant"
    node.default["create_cont"]["cwd"] = "/home/vagrant"
    node.default["create_cont"]["arch"] = "x64"
end

server_data = data_bag_item('server', node[:hostname])
classes_data = search(:classes, "uid:#{node[:hostname]}")
#nodeで動いているコンテナ(stateは無関係)
launched_cont = []
#databagに記載のあるコンテナ
list_cont = []
#databagに記載のないコンテナ
unlist_cont = []

ruby_block "configure stage" do
    block do

        shell_out("/snap/bin/lxc list -c n -f csv").stdout.each_line{|line|
            launched_cont.push(line.chomp)
        }
        classes_data.each do |result|
            list_cont.push(result['id'])
        end
        unlist_cont = launched_cont - list_cont
        Chef::Log.info "launched_cont #{launched_cont}"
        Chef::Log.info "list_cont #{list_cont}"
        Chef::Log.info "unlist_cont #{unlist_cont}"


        #databagに記載のないコンテナの停止(/削除)
        unlist_cont.each do |result|

            Chef::Log.info "unlist_cont #{result}"
            status = shell_out("usr/bin/test $(/snap/bin/lxc list #{result} -c s -f csv) = 'RUNNING'").stdout
            Chef::Log.info "status #{status}"

            recipe.bash "lxc stop #{result}" do
                user node["create_cont"]["user"]
                group 'lxd'
                cwd node["create_cont"]["cwd"]
                action :run
                only_if "/usr/bin/test $(/snap/bin/lxc list #{result} -c s -f csv) = 'RUNNING'"
                #only_if { status == "RUNNING" }
                code "/snap/bin/lxc stop #{result}"
            end

            #コンテナを削除しないならコメントアウト
            recipe.bash "lxc delete #{result}" do
                user node["create_cont"]["user"]
                group 'lxd'
                cwd node["create_cont"]["cwd"]
                action :run
                code "/snap/bin/lxc delete #{result}"
            end

            recipe.file "#{node["create_cont"]["cwd"]}/rasapp/public/classes/contents/#{result['cid']}.json" do
                owner node["create_cont"]["user"]
                group node["create_cont"]["user"]
                action :delete
            end

            recipe.file "#{node["create_cont"]["cwd"]}/rasapp/public/classes/images/#{result['cid']}.png" do
                owner node["create_cont"]["user"]
                group node["create_cont"]["user"]
                action :delete
            end

        end

    end
end


ruby_block "setup container stage" do
    block do

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

            recipe.ruby_block "check container #{result['cid']}-#{result['uid']}" do
                block do
                    #cont = `/snap/bin/lxc list #{result['cid']}-#{result['uid']} -c n -f csv`
                    #Chef::Log.info cont
                    #if cont == '' then
                    if !launched_cont.include? "#{result['cid']}-#{result['uid']}" then
                        p "no container"
                    end
                end
                #if `/snap/bin/lxc list #{result['cid']}-#{result['uid']} -c n -f csv` == '' then
                if !launched_cont.include? "#{result['cid']}-#{result['uid']}" then
                    notifies :run, "bash[lxc init #{result['cid']}-#{result['uid']}]", :immediately
                end
            end

            recipe.bash "lxc init #{result['cid']}-#{result['uid']}" do
                user node["create_cont"]["user"]
                group 'lxd'
                cwd node["create_cont"]["cwd"]
                action :nothing
                notifies :run, "bash[lxc config device add #{result['cid']}-#{result['uid']} http proxy]", :immediately
                code "/snap/bin/lxc init chefserver:#{node["create_cont"]["arch"]}-#{result['cid']} #{result['cid']}-#{result['uid']}"
            end

            recipe.bash "lxc config device add #{result['cid']}-#{result['uid']} http proxy" do
                user node["create_cont"]["user"]
                group 'lxd'
                cwd node["create_cont"]["cwd"]
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

            recipe.bash "lxc start #{result['cid']}-#{result['uid']}" do
                user node["create_cont"]["user"]
                group 'lxd'
                cwd node["create_cont"]["cwd"]
                action :nothing
                code "/snap/bin/lxc start #{result['cid']}-#{result['uid']}"
            end

            recipe.file "#{node["create_cont"]["cwd"]}/rasapp/public/classes/contents/#{result['cid']}.json" do
                content lazy{"{\"ip\":\"\",\"port\":\"#{result['port']}\"}"}
                mode '0755'
                owner node["create_cont"]["user"]
                group node["create_cont"]["user"]
                action :create
            end

            recipe.cookbook_file "#{node["create_cont"]["cwd"]}/rasapp/public/classes/images/#{result['cid']}.png" do
                source "#{result['cid']}.png"
                owner node["create_cont"]["user"]
                group node["create_cont"]["user"]
                mode '0755'
                action :create
            end
        end
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