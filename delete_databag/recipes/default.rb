#attributeから変数を設定する

#databagの削除
ruby_block "delete classes databag items" do
    block do
        databag_item = Chef::DataBagItem.new
        databag_item.data_bag('classes')
        databag_item.delete(node["delete_databag"]["databag"]["item"])
    end
    action :run
end