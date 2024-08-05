# Copyright Vespa.ai. All rights reserved.
require 'rpcwrapper'
require 'storagemessage'


slobrok = RpcWrapper.new("test-fledsbo", 7713)
names, locations = slobrok.slobrok_admin_listAllRpcServers()
loc_re = /\w*\/([\w\.-]*):(\d*)/

names.each_index do |i|

  match = loc_re.match(locations[i]);
  if !match then
    puts "#{locations[i]} didn't match regexp"
    next
  end

  puts "Connecting to #{names[i]} at #{match[1]}:#{match[2].to_i}"

  wrap = RpcWrapper.new(match[1], match[2].to_i)

  ret = wrap.vespa_storage_connect(names[i])
  puts "connect returned #{ret[0]}"

  cmd = AdminCommand.new
  cmd.params['command'] = 'getcollection'
  result = wrap.vespa_storage_send(cmd.serialize)
  reply = AdminReply.new
  reply.deserialize(result[0])

  puts "Admin returned with result #{reply.return_code}"

  cmd = PingCommand.new
  cmd.data = "RUOK"
  result = wrap.vespa_storage_send(cmd.serialize)
  reply = PingReply.new
  reply.deserialize(result[0])

  puts " returned with result #{reply.return_code}, data #{reply.data}"
end
