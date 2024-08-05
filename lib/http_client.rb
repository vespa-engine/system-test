# Copyright Vespa.ai. All rights reserved.

require 'environment'

class HttpClient

  CLIENT_LIB = "#{Environment.instance.vespa_home}/lib/jars/vespa-feed-client-cli-jar-with-dependencies.jar"

  def initialize(node)
    @node = node
  end

  def getcmd(file, host, port, route, num_connections)
    "java -server -verbose:gc -XX:NewRatio=1 -Xms8g -Xmx8g -jar #{CLIENT_LIB} --vespaTls --file #{file} --host #{host} --port #{port} --route #{route} -v --numPersistentConnectionsPerEndpoint #{num_connections} --maxpending 20000"
  end

  def feed(file, host, port, route, num_connections=4)
    @node.execute(getcmd(file, host, port, route, num_connections))
  end
end
