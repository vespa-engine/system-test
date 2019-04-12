# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'environment'

class HttpClient

  CLIENT_LIB = "#{Environment.instance.vespa_home}/lib/jars/vespa-http-client-jar-with-dependencies.jar"
  CLIENT_CLASS = "com.yahoo.vespa.http.client.runner.Runner"

  def initialize(node)
    @node = node
  end

  def getcmd(file, host, port, route, num_connections)
    "java -server -verbose:gc -XX:NewRatio=1 -Xms8g -Xmx8g -cp #{CLIENT_LIB} #{CLIENT_CLASS} --file #{file} --host #{host} --port #{port} --route #{route} -v --numPersistentConnectionsPerEndpoint #{num_connections} --maxpending 20000"
  end

  def feed(file, host, port, route, num_connections=4)
    @node.execute(getcmd(file, host, port, route, num_connections))
  end
end
