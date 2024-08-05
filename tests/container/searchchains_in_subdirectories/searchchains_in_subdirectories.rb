# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class SearchchainsInSubdirectories < SearchContainerTest

  def timeout_seconds
    return 1600
  end


  def setup
    set_owner("bratseth")
    set_description("Tests that it is possible to put search chains in subdirectories under search/chains")
  end

  def test_searchains_in_subdirectories
    add_bundle_dir(File.expand_path(selfdir), "mybundle")
    deploy(selfdir+"app-modular")
    start

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
    stop
  end

  def teardown
  end
end
