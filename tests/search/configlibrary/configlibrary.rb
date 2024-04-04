# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class ConfigLibrary < IndexedStreamingSearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_description("Tests that the config library handles config proxy being killed")
    set_owner("musum")
    @query=""
    deploy_app(SearchApp.new.sd(selfdir+"sd1/book.sd"))
    start
  end

  def test_proxy_crashing
    @query="you"

    feed_and_wait_for_docs("book", 2, :file =>selfdir+"feed.json")

    # check correct results with sd1
    assert_result("query=#{@query}", selfdir+"result.sd1.json")

    # kill config proxy with TERM signal
    kill_proxy(vespa.adminserver)

    # deploy and compare with second sd
    deploy_and_compare("sd2")

    # Need to sleep a while to trigger bug
    sleep 30

    # deploy and compare with first sd
    deploy_and_compare("sd1")

    # kill config proxy with TERM signal
    puts "Killing the second time"
    kill_proxy(vespa.adminserver)

    # deploy and compare with second sd
    deploy_and_compare("sd2")
  end

  def deploy_and_compare(sd_dir)
    deploy_app(SearchApp.new.sd(selfdir+"#{sd_dir}/book.sd"))
    poll_compare("query=#{@query}", selfdir+"result.#{sd_dir}.json", nil, nil, 120)
  end

  def turn_on_debug_logging
    vespa.adminserver.logctl("searchnode:config", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:config.subscription", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:frtconfigrequest", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:frtconnection", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:frtsource", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:configagent", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.configmanager", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:fnet", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=off,spam=off")
    vespa.adminserver.logctl("searchnode:proton.server.protonconfigmanager", "debug=off,spam=off")
    vespa.adminserver.logctl("searchnode:proton.server.configmanager", "debug=on,spam=on")
  end

  def kill_proxy(node)
    pscommand = node.execute("ps axuww").strip
    lines = pscommand.split("\n")
    pid = nil
    lines.each {|line|
      if line.include? "ProxyServer"
        if !line.include? "runserver"
          puts "#{line}"
          pid = line.split("\s")[1]
          puts "pid=#{pid}"
        end
      end
    }
    node.execute("kill -TERM #{pid}")
  end

  def teardown
    stop
  end

end
