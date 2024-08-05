# Copyright Vespa.ai. All rights reserved.

require 'rpc/rpcwrapper'
require 'environment'

module Perf

  class ConfigStressTester
    def initialize(node, hostname, port, bundle, serverhost, serverport)
      @node = node
      @hostname = serverhost # hostname for StressTester RPC server
      @port = serverport # port for StressTester RPC server
      cmd = "VESPA_CONFIG_SOURCES=\"#{hostname}:#{port}\" #{Environment.instance.vespa_home}/bin/java -cp #{bundle}:#{Environment.instance.vespa_home}/lib/jars/config.jar:#{Environment.instance.vespa_home}/lib/jars/config-lib.jar:#{Environment.instance.vespa_home}/lib/jars/vespajlib.jar:#{Environment.instance.vespa_home}/lib/jars/jrt.jar:#{Environment.instance.vespa_home}/lib/jars/vespalog.jar com.yahoo.vespa.config.benchmark.StressTester -c #{hostname} -p #{port} -serverport #{serverport} -class com.yahoo.vespa.systemtest.gen.TestStub -d"
      puts(cmd)
      @pid = @node.execute_bg("#{cmd}")
      puts("Executing cmd with pid #{@pid}")
      @wrapper = nil
    end

    def wrapper
      @wrapper ||= RpcWrapper.new(@hostname, @port, nil, 300)
    end

    def start(num_clients)
      wrapper.start(num_clients.to_i)[0]
    end

    def verify(generation, verificationfile, timeout)
      destdir = Environment.instance.tmp_dir
      name = File.basename(verificationfile)
      @node.copy(verificationfile, destdir)
      retval = wrapper.verify(generation.to_i, "#{destdir}/#{name}", timeout.to_i)
      return retval
    end

    def stop
      wrapper.stop[0]
    end

    def shutdown
      @node.kill_pid(@pid)
    end
  end
end
