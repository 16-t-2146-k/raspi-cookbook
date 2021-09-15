require "json"

server = {}
hostname = []
search(:server, "*:*").each do |result|
    hostname.push(result['id'])
    server[result['id']] = {'id' => result['id'],'hostname' => result['hostname'],'ip' => result['ip'],'port' => result['port'],'used_port' => result['used_port']}
end


search(:new_user, "*:*").each do |student|
    host = ''
    #ip = ''
    port = ''
    _port = ''
    _used_port = ''
    min_num = 9999

    hostname.each do |h|
        if server[h]['used_port'].length < min_num and !server[h]['port'].empty? then
            host = server[h]['hostname']
            min_num = server[h]['used_port'].length
        end
    end

    p host
    p min_num

    if host == '' then
        break
    end

    #ip = server[host]['ip']
    _port = server[host]['port']
    _used_port = server[host]['used_port']
    port = _port.shift
    _used_port.push(port)
    server[host]['port'] = _port
    server[host]['used_port'] = _used_port

    p server


    # cls = Chef::DataBag.new
    # cls.name(student['cid'])
    # cls.create

    databag_item = Chef::DataBagItem.new
    databag_item.data_bag(student['cid'])
    raw_data = {
            'id' => student['uid'],
            'uid' => student['uid'],
            'cid' => student['cid'],
            'host' => host,
            'port' => port,
        }
    databag_item.raw_data = raw_data
    databag_item.create
    databag_item.save

    new_user = Chef::DataBagItem.new
    new_user.data_bag('new_user')
    new_user.destroy('new_user', student['id'])

end

hostname.each do |h|
    raw_data = data_bag_item('server', h)
    databag_item = Chef::DataBagItem.new
    databag_item.data_bag('server')
    databag_item.raw_data = {
        'id' => raw_data['id'],
        'hostname' => raw_data['hostname'],
        'ip' => raw_data['ip'],
        'port' => server[h]['port'],
        'used_port' => server[h]['used_port'],
    }
    databag_item.save
end

