# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentId < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Test that a searcher that takes ComponentId as ctor arg but fails to call super(id) still gets the correct ID.")
    add_bundle(selfdir+"ForgetfulSearcher.java")
    deploy(selfdir+"app")
    start
  end

  def test_searcher_that_forgets_to_set_id
    # See bug #4036397
    result = search("query=test")
    assert_equal("Hello world", result.hit[0].field["message"])
  end

  def teardown
    stop
  end

end
