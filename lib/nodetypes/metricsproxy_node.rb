# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class MetricsProxyNode < ContainerNode
  def initialize(*args)
    super(*args)
  end

  def get_wrapper
    return @wrapper if @wrapper
    host = "localhost"
    @testcase.puts `ps auxww`
    @testcase.puts "Trying to connect to metrics proxy on host: #{host}"
    done = nil
    retries = 0

    while not done and retries < 60
      retries += 1
      begin
        @wrapper = RpcWrapper.new(host, 19095, tls_env())
      rescue Errno::ECONNREFUSED
        sleep 1
        next
      end
      done = true
    end

    @wrapper
  end
end
