#attributeから変数を設定する

#databagの削除
ruby_block "delete classes databag items" do
    block do
        Chef::Log.info "item #{node['override_attributes']['delete_databag']['item']}"
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('classes')
        databag_item.delete(node['override_attributes']['delete_databag']['item'])
    end
    action :run
end