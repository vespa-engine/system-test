# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Bug_1450048 < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("johansen")
    juniper = ConfigOverride.new("vespa.config.search.summary.juniperrc").add("length", 313).add("surround_max", 3)
    specialtokens = ConfigOverride.new("vespa.configdefinition.specialtokens").
                                   add(ArrayConfig.new("tokenlist").append.
                                     add(0, ConfigValue.new("name", "default")).
                                     add(0, ArrayConfig.new("tokens").append.
                                                add(0, ConfigValue.new("token", "c++")).
                                                add(1, ConfigValue.new("token", "a+")).
                                                add(2, ConfigValue.new("token", "c#")).
                                                add(3, ConfigValue.new("token", "vc++")).
                                                add(4, ConfigValue.new("token", ".net")).
                                                add(5, ConfigValue.new("token", "asp.net")).
                                                add(6, ConfigValue.new("token", "pl/sql")).
                                                add(7, ConfigValue.new("token", "at&amp;t")).
                                                add(8, ConfigValue.new("token", "wal-mart")).
                                                add(9, ConfigValue.new("token", ".mac"))))
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").
                             config(juniper).
                             config(specialtokens))
    start
  end

  def test_specialtokens_bug1450048
    feed_and_wait_for_docs("music", 1, :file => selfdir+"musicdata.xml", :cluster => "music")

    puts "sanity check"
    assert_hitcount("query=sddocname:music", 1)

    resp = selfdir+"result."
    puts "test queries..."

    # foo does not appear
    assert_hitcount("query=content:foo", 0)

    # c++ does not appear in content, just title
    assert_hitcount("query=content:c%2B%2B", 0)

    # .net does appear in content
    assert_result("query=content:%2Enet", resp + "net.xml")

    # c does not appear in content
    assert_hitcount("query=content:c", 0)

    # net does not appear in content, only as .net
    assert_hitcount("query=content:net", 0)

    # c++ does appear in title
    assert_result("query=title:c%2B%2B", resp + "c++.xml")
  end

  def teardown
    stop
  end

end
