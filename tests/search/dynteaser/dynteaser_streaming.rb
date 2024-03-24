# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'streaming_search_test'

class DynTeaserStreaming < StreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_stem_config_streaming
    set_description("Test that we can set the juniper stem config when using streaming search")
    deploy_app(SearchApp.new.sd(selfdir+"stem.sd").
                             config(ConfigOverride.new("vespa.config.search.summary.juniperrc").
                                                   add("stem_min_length", 1).
                                                   add("stem_max_extend", 8)))
    start
    feed(:file => selfdir + "stem.json")
    wait_for_hitcount("query=sddocname:stem&streaming.userid=1", 1)

    assert_stem_config("stop receiving announcements",          "query=s")
    assert_stem_config("<hi>stop</hi> receiving announcements", "query=s*")
    assert_stem_config("<hi>stop</hi> receiving announcements", "query=st")
    assert_stem_config("stop receiving announcements",          "query=anno")
    assert_stem_config("stop receiving <hi>announcements</hi>", "query=anno*")
    assert_stem_config("stop receiving <hi>announcements</hi>", "query=annou")
  end

  def assert_stem_config(expected, query)
    result = search(query + "&streaming.userid=1")
    assert_equal(expected, result.hit[0].field["f1"])
  end

  def teardown
    stop
  end

end
