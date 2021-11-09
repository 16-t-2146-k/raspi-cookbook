#attributeから変数を設定する

#databagの削除
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