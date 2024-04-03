# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'

class StreamingMatcherNormalizeSubject < StreamingSearchTest

  def timeout_seconds
    3600
  end

  def test_streaming_mailchecksum
    set_owner("vekterli")
    set_description("Simple test for streaming matcher (config model and basic functionality)")
    deploy_app(singlenode_streaming_2storage(selfdir+"musicsearch.sd"))
    start
    feedfile(selfdir+"feed_subjects.xml")
    assert_result("query=sddocname:musicsearch&hits=0&streaming.userid=1234&streaming.headersonly=true&select=all(group(normalizesubject(title)) each(output(count())))", selfdir+"normalizesubject.result.json")
  end

  def teardown
    stop
  end


end
