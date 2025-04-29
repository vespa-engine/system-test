require 'search/streamingmatcher/streaming_matcher'

class StreamingMatcherJuniperConfig < StreamingMatcher

  def test_juniper_config_subscribe
    set_owner("hmusum")
    set_description("Test that we can control windowsize. It should fail with this reduced fallback size")
    deploy_app(SearchApp.new
               .streaming()
               .sd(selfdir+"substrsnippet.sd")
               .config(ConfigOverride.new("vespa.config.search.summary.juniperrc").add("winsize_fallback_multiplier", 1.0)))
    start
    feed(:file => selfdir + "substrsnippet.json")
    wait_for_hitcount('query=sddocname:substrsnippet&streaming.userid=1&type=all', 3)

    # english
    assert_hitcount('query=f1:or&streaming.userid=1&type=all', 0);
    # single hit
    assert_result('query=f1:%2Aeep%2A+f2:bil&streaming.userid=1&type=all', selfdir + "substrsnippet.eepbil.result.json", nil, ["f1","f2","s1"])
  end

end
