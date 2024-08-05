# Copyright Vespa.ai. All rights reserved.
require 'rpc/packet'
require 'timeout'

class RpcCommandTimeout < StandardError
  def message
    "Command timed out."
  end
end

class CommandCaller

  RPC_REQUEST = 100
  RPC_REPLY = 101
  RPC_ERROR = 102

  @@req_id = 0

  public

  def initialize(method, in_types, out_types, timeout=15)
    @method = method
    @in_types = in_types
    @out_types = out_types
    @rpc_timeout = timeout
  end

  def call(socket, *params)
    cmd = CommandPacket.new(@in_types, @method)
    cmd.pcode = RPC_REQUEST
    @@req_id = (@@req_id + 2) % (2**30) #wrap around
    cmd.req_id = @@req_id
    cmd.parameters = params
    cmd.no_reply = @out_types.length == 0

    socket << cmd.to_s

    return [] if cmd.no_reply

    reply = ReplyPacket.new(@out_types, cmd)
    reply.req_id = -1

    begin
      Timeout::timeout(@rpc_timeout, RpcCommandTimeout) do
        while reply.req_id != cmd.req_id
          reply.read(socket)
        end
      end
 #is this useful?
 #  rescue RpcCommandTimeout
 #    raise RuntimeError, "Command timed out", caller
    end

    if reply.pcode == RPC_ERROR then
      err_code, err_msg_len, err_msg = reply.data.unpack('nNa*')
      raise RuntimeError, "Server returned error #{err_code} - #{err_msg}", caller
    end

    if reply.data == nil then
      raise RuntimeError, "Server returned no data", caller
    end

    reply.ret_values
  end
end
