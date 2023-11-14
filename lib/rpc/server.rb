# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'socket'
require 'packet'


class Server
  def run_server(port)
    server = TCPServer.new('localhost', port)
    while (session = server.accept)
      print session
      handle_session(session)
    end
  end
  def handle_session(session)
    while !session.eof()
      cmd = CommandPacket.new("", "")
      cmd.read(session)
      cmd.in_types = get_in_types(cmd.method)
      reply = handle_command(cmd)
      session << reply
    end
  end

  def handle_command(cmd)
    command = cmd.method
    parameters = cmd.parameters
    reply = ReplyPacket.new(cmd, get_out_types(command))
    reply.ret_values = self.send(command, *parameters)
    reply
  end

  def get_in_types(command)
    info = self.send(command + "_info")
    in_types = ""
    info[1].each { |param| in_types += param[1][0] }
    in_types
  end
  def get_out_types(command)
    info = self.send(command + "_info")
    in_types = ""
    info[2].each { |param| in_types += param[1][0] }
    in_types
  end
end
