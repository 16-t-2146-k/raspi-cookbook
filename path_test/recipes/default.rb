ruby_block 'check container' do
    block do
        path = `whoami`
        puts path
    end
end

search(:prog, "host:#{node['name']}").each do |result|
    ruby_block 'print user info' do
        block do
            #Chef::Log.info result['uid']
            puts result['uid']
        end
    end
end
