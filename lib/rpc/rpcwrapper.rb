# Copyright Vespa.ai. All rights reserved.
require 'rpc/command'
require 'socket'
require 'json'
require 'tls_env'

class RpcWrapper

  public
  def initialize(hostname, port, tls_env=nil, timeout=120)
    @hostname = hostname
    @port = port
    @printdoc = false
    @methods = Hash.new
    @tls_env = tls_env || TlsEnv.new
    add_method("frt.rpc.getMethodList", "", "SSS", timeout)
    add_method("frt.rpc.getMethodInfo", "s", "sssSSSS", timeout)

    methods, parameters, returns = self.frt_rpc_getMethodList()
    methods.each do |method|
      desc, in_types, out_types, in_names, in_desc, out_names, out_desc =
      self.frt_rpc_getMethodInfo(method)
      add_method(method, in_types, out_types, timeout)
      if @printdoc then
        puts " Doc: #{desc}"
        puts " Parameters:"
        in_names.each_index { |i| puts "  #{in_names[i]}: #{in_desc[i]}" }
        puts " Returns:"
        out_names.each_index { |i| puts "  #{out_names[i]}: #{out_desc[i]}" }
      end
    end
  end

  def add_method(method, in_types, out_types, timeout)
    local_method = method.gsub(/\./, '_');
    puts "adding method #{local_method} (#{in_types}->#{out_types})" if @printdoc
    proxy = CommandCaller.new(method, in_types, out_types, timeout)
    self.instance_eval do
      mod = Module.new
      mod.send(:define_method, local_method.to_sym) { |*x|
         begin
           if not @socket
             @socket = TCPSocket.new(@hostname, @port)
             if @tls_env.ssl_ctx
               @socket = OpenSSL::SSL::SSLSocket.new(@socket, @tls_env.ssl_ctx)
               @socket.connect
             end
           end
           proxy.call(@socket, *x)
         rescue
           @socket.close if @socket
           @socket = nil
           raise
         end
      }
      extend(mod)
    end
  end

end
