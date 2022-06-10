# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DynTeaser < IndexedSearchTest

  def setup
    set_owner("geirst")
    set_description("Test of dynamic teaser support")
    @debug_log_enabled = false
  end

  def compare(query, file, field)
    # run all queries twice to check caching
    assert_field(query, file, field, true)
    assert_field(query, file, field, true)
    # explicitly avoid cache
    assert_field(query + "&nocache", file, field, true)
    # then try normal again
    assert_field(query, file, field, true)
  end

  def enable_dyn_teaser_debug_logging
    vespa.search["search"].searchnode.each_value do |proton|
      proton.logctl2("searchlib.docsummary.dynamicteaserdfw", "all=on")
      proton.logctl2("juniper.sumdesc", "all=on")
    end
  end

  def test_dyn_teaser
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd"))
    start
    enable_dyn_teaser_debug_logging if @debug_log_enabled

    feed_and_wait_for_docs("cjk", 34, :file => selfdir+"dynteaser.34.xml")

    puts "Query: english"
    compare('query=content:time&type=all', selfdir+"time.result.json", "dyncontent")
    compare('query=content:time&type=all', selfdir+"time.result.json", "content2")
    compare('query=content:time&type=all', selfdir+"time.result.json", "content3")

    # Return if CentOS, code below depends on linguistics library suppporting CJK languages
    return if linux_distribution_CentOS?

    puts "Query: korean"
    compare('query=content:%EB%8F%8C%EB%93%A4%EC%9D%B4+content:%EC%9E%A5%EA%B8%B0%EB%82%98&language=ko&type=all', selfdir+"ko.result.json", "dyncontent")
    compare('query=content:%EB%8F%8C%EB%93%A4%EC%9D%B4+content:%EC%9E%A5%EA%B8%B0%EB%82%98&language=ko&type=all', selfdir+"ko.result.json", "content2")
    compare('query=content:%EB%8F%8C%EB%93%A4%EC%9D%B4+content:%EC%9E%A5%EA%B8%B0%EB%82%98&language=ko&type=all', selfdir+"ko.result.json", "content3")

    #token: %E5%9F%BA%E6%9C%AC basic
    #token: %E5%B1%80%E9%9D%A2 aspect
    #token: %E6%9C%80%E7%BB%88 finally
    #token: %E8%A7%84%E5%88%99 regular
    #token: %E9%97%AE%E9%A2%98 question

    puts "Query: simplified chinese"
    compare('query=content:%E5%9F%BA%E6%9C%AC+content:%E9%97%AE%E9%A2%98&language=zh-hans&type=all', selfdir+"cs.result.json", "dyncontent")
    compare('query=content:%E5%9F%BA%E6%9C%AC+content:%E9%97%AE%E9%A2%98&language=zh-hans&type=all', selfdir+"cs.result.json", "content2")
    compare('query=content:%E5%9F%BA%E6%9C%AC+content:%E9%97%AE%E9%A2%98&language=zh-hans&type=all', selfdir+"cs.result.json", "content3")

  end

  def test_long_dyn_teaser
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd").
                             config(ConfigOverride.new("vespa.config.search.summary.juniperrc").
                                                   add("length", 360).
                                                   add("surround_max", 360).
                                                   add("min_length", 300)))
    start

    feed_and_wait_for_docs("cjk", 1, :file => selfdir+"dynteaser.1.xml")

    puts "Query: english"
    compare('query=content:time&type=all', selfdir+"time.long.result.json", "content3")
  end

  def test_fallback_none
    deploy_app(SearchApp.new.sd(selfdir+"fallback.sd").
                             config(ConfigOverride.new("vespa.config.search.summary.juniperrc").
                                                   add("prefix", false).
                                                   add("length", 64).
                                                   add("min_length", 32)))
    start

    feed_and_wait_for_docs("fallback", 1, :file => selfdir+"fallback.1.xml")

    result = search("report")
    assert_equal(1, result.hitcount)
    assert_equal("<hi>Report</hi> Kaw-Liga;Johnny<sep />",
                 result.hit[0].field["dyncontent"])
    assert_equal("", result.hit[0].field["content2"])
    assert_equal("", result.hit[0].field["content3"])
    assert_equal("", result.hit[0].field["content4"])
    assert_equal(nil, result.hit[0].field["content5"])

    result = search("system")
    assert_equal(1, result.hitcount)
    assert_equal("", result.hit[0].field["dyncontent"])
    assert_equal("<hi>System</hi> Kaw-Liga;Johnny<sep />",
                 result.hit[0].field["content2"])
    assert_equal("", result.hit[0].field["content3"])
    assert_equal("", result.hit[0].field["content4"])
    assert_equal(nil, result.hit[0].field["content5"])
  end

  def test_fallback_prefix
    deploy_app(SearchApp.new.sd(selfdir+"fallback.sd").
                             config(ConfigOverride.new("vespa.config.search.summary.juniperrc").
                                                   add("prefix", true).
                                                   add("length", 64).
                                                   add("min_length", 32)))
    start

    feed_and_wait_for_docs("fallback", 1, :file => selfdir+"fallback.1.xml")

    result = search("report")
    assert_equal(1, result.hitcount)
    assert_equal("<hi>Report</hi> Kaw-Liga;Johnny<sep />",
                 result.hit[0].field["dyncontent"])
    assert_equal("System Kaw-Liga<sep />",
                 result.hit[0].field["content2"])
    assert_equal("Search Kaw-Liga<sep />",
                 result.hit[0].field["content3"])
    assert_equal("", result.hit[0].field["content4"])
    assert_equal(nil, result.hit[0].field["content5"])

    result = search("system")
    assert_equal(1, result.hitcount)
    assert_equal("Report Kaw-Liga<sep />",
                 result.hit[0].field["dyncontent"])
    assert_equal("<hi>System</hi> Kaw-Liga;Johnny<sep />",
                 result.hit[0].field["content2"])
    assert_equal("Search Kaw-Liga<sep />",
                 result.hit[0].field["content3"])
    assert_equal("", result.hit[0].field["content4"])
    assert_equal(nil, result.hit[0].field["content5"])
  end

  def teardown
    stop
  end

end
