#attributeから変数を設定する

#databagの削除
ruby_block "delete classes databag items" do
    block do
        #override_attributes
        Chef::Log.info node['delete_databag']['item']
        databag_item = data_bag_item('classes', node['delete_databag']['item'])
        Chef::Log.info databag_item
        #databag_item.load('classes',node['delete_databag']['item'])
        databag_item.delete
    end
    action :run
end