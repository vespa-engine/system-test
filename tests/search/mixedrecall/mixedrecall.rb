# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MixedRecall < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test of mixed recall between index and attributes searching for sddocname")
  end

  def test_sddocname
    deploy_and_check_for_warning
    vespa.start

    feed_and_wait_for_docs("music", 10, {:file => selfdir+"/data/music-basic.json"})

    assert_hitcount("query=bad", 5)

    # Search for numeric attribute which has "attribute | index" in indexing statement
    assert_hitcount("query=year:2000", 2)
  end

  def deploy_and_check_for_warning
    message = /WARNING: For schema 'music', field 'year': Changed to attribute because numerical indexes \(field has type int\) is not currently supported. Index-only settings may fail. Ignore this warning for streaming search./

    output = deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    assert_match(Regexp.new(message), output)
  end

  def teardown
    stop
  end

end
