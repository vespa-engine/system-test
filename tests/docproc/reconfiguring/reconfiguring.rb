# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'docproc_test'

class Reconfiguring < DocprocTest

  def setup
    set_owner("arnej")
    add_bundle(DOCPROC + "WorstMusicDocProc.java")
    add_bundle(selfdir + "AppleDocProc.java")
    add_bundle(selfdir + "BananaDocProc.java")
    output = deploy(selfdir + "setup-1x1-a", DOCPROC + "data/worst.sd")

    if vespa.adminserver
      vespa.adminserver.logctl("container:com.yahoo.container.jdisc.messagebus.SessionCache", "debug=on") 
      vespa.adminserver.logctl("container:com.yahoo.docproc.jdisc.DocumentProcessingHandler", "debug=on")
    end

    start
    @container = vespa.container.values.first
    wait_for_application(@container, output)
  end

  def test_multichain_reconfiguring
    #check that session 'split' has started (created in cache by clientprovider or serverprovider):
    numChainSessionMessages = assert_log_matches(/Creating new intermediate session chain.split/, 0)
    assert_equal(1, numChainSessionMessages)
    #check that session 'split' was cached (retrieved from cache by clientprovider or serverprovider):
    numChainSessionMessages = assert_log_matches(/Reusing intermediate session chain.split/, 0)
    assert_equal(1, numChainSessionMessages)

    numCallStackSplitMessages = assert_log_matches(/Setting up call stack for chain split/, 0)
    assert_equal(1, numCallStackSplitMessages)

    #check that session is registered in slobrok:
    ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
    assert(ret =~ /banana.container.0.chain.split/)

    puts "[DEPLOY] changing to setup-1x1-b"
    output = deploy(selfdir + "setup-1x1-b", DOCPROC + "data/worst.sd")
    # Wait until container has reloaded config
    wait_for_application(@container, output)

    # on reloading config, we currently do not get any new messages about sessions,
    # check that the number of messages is the same as above.
    numChainSessionMessages = assert_log_matches(/Reusing intermediate session chain.split/, 0)
    assert_equal(1, numChainSessionMessages)
    numChainSessionMessages = assert_log_matches(/Creating new intermediate session chain.split/, 0)
    assert_equal(1, numChainSessionMessages)

    # Call stack will be setup again
    numCallStackSplitMessages = assert_log_matches(/Setting up call stack for chain split/, 0)
    assert_equal(2, numCallStackSplitMessages)

    #check that session is still present in slobrok:
    ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
    assert(ret =~ /banana.container.0.chain.split/)

    puts "[DEPLOY] changing to setup-1x1-c"
    output = deploy(selfdir + "setup-1x1-c", DOCPROC + "data/worst.sd")
    # Wait until container has reloaded config
    wait_for_application(@container, output)

    #check that session 'shake' has started (created in cache by clientprovider or serverprovider):
    numChainSessionMessages = assert_log_matches(/Creating new intermediate session chain.shake/, 0)
    assert_equal(1, numChainSessionMessages)
    #check that session 'shake' was cached (retrieved from cache by clientprovider or serverprovider):
    numChainSessionMessages = assert_log_matches(/Reusing intermediate session chain.shake/, 0)
    assert_equal(1, numChainSessionMessages)

    #check that session is registered in slobrok:
    ret = "empty"
    60.times do |x|
        ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
        if ret =~ /banana.container.0.chain.shake/
            break
        end
        sleep 1
    end
    assert(ret =~ /banana.container.0.chain.shake/)

    #check that session for previous chain is still present in slobrok:
    ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
    assert(ret =~ /banana.container.0.chain.split/)

    # New call stack will be setup
    numCallStackShakeMessages = assert_log_matches(/Setting up call stack for chain shake/, 0)
    assert_equal(1, numCallStackShakeMessages)

    # Call stack will be setup again
    numCallStackSplitMessages = assert_log_matches(/Setting up call stack for chain split/, 0)
    assert_equal(3, numCallStackSplitMessages)

    puts "[DEPLOY] changing to setup-1x1-d"
    output = deploy(selfdir + "setup-1x1-d", DOCPROC + "data/worst.sd")
    # Wait until container has reloaded config
    wait_for_application(@container, output)

    #check that session is still registered in slobrok:
    ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
    assert(ret =~ /banana.container.0.chain.shake/)

    # Call stack will not be setup again for removed chain
    numCallStackSplitMessages = assert_log_matches(/Setting up call stack for chain split/, 0)
    assert_equal(3, numCallStackSplitMessages)

    # New call stack will be setup again
    numCallStackShakeMessages = assert_log_matches(/Setting up call stack for chain shake/, 0)
    assert_equal(2, numCallStackShakeMessages)

    sleep 65 # Wait for deconstruction of providers, and then a slobrok graceperiod of 5 seconds
    #check that session for previous chain is no longer present in slobrok:
    ret = vespa.adminserver.execute("vespa-slobrok-cmd 19099 slobrok.admin.listAllRpcServers")
    puts "slobrok\n" + ret
    assert_nil(ret =~ /banana.container.0.chain.split/)
  end

  def teardown
    if vespa.adminserver
      vespa.adminserver.logctl("container:com.yahoo.container.jdisc.messagebus.SessionCache", "debug=on")
      vespa.adminserver.logctl("container:com.yahoo.docproc.jdisc.DocumentProcessingHandler", "debug=on")
    end
    stop
  end

end
