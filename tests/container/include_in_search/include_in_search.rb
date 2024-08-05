# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class IncludeInSearch < SearchContainerTest

  def timeout_seconds
    return 1600
  end


  def setup
    set_owner("gjoranv")
    set_description("Verify that 'include' works under'search', i.e. that search setup can be put in separate files.")
    add_bundle_dir(File.expand_path(selfdir), "mybundle")
    deploy(selfdir + "app")
    start
  end

  def test_include_in_search
    result = search("query=test&searchChain=inline")
    assert(result.hit.length==2)
    message = result.hit[0].field["message"]
    message2 = result.hit[1].field["message2"]
    assert_equal("Hello world", message)
    assert_equal("Hello world 2", message2)

    result = search("query=test&searchChain=chain2")
    assert(result.hit.length==2)
    message = result.hit[0].field["message"]
    message2 = result.hit[1].field["message2"]
    assert_equal("Hello world", message)
    assert_equal("Hello world 2", message2)

    result = search("query=test&searchChain=chain3_1")
    assert(result.hit.length==1)
    message = result.hit[0].field["message"]
    assert_equal("Hello world", message)

    result = search("query=test&searchChain=chain3_2")
    assert(result.hit.length==2)
    message = result.hit[0].field["message"]
    message2 = result.hit[1].field["message2"]
    assert_equal("Hello world", message)
    assert_equal("Hello world 2", message2)

    result = search("query=test")
    assert(result.hit.length==1)
    message = result.hit[0].field["message"]
    assert_equal("Hello world", message)
  end

  def teardown
    stop
  end

end
