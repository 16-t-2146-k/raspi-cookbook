#attributeから変数を設定する

#databagの削除
ruby_block "create classes databag items" do
    block do
        #override_attributes
        Chef::Log.info node['create_databag']['item']
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('classes')
        databag_item.raw_data = {
            'id' => "#{node['create_databag']['item']}-#{node['hostname']}",
            'uid' => node['hostname'],
            'cid' => node['create_databag']['item'],
            'port' => "",
        }
        databag_item.save
    end
    action :run
end