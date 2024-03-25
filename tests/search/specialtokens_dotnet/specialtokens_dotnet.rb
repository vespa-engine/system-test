# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class SpecialTokensDotNet < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.
               sd("#{selfdir}/test.sd").
               config(ConfigOverride.new("vespa.configdefinition.specialtokens").
                      add(ArrayConfig.new("tokenlist").
                          add(0, ConfigValue.new("name", "default")).
                          add(0, ArrayConfig.new("tokens").
                              add(0, ConfigValue.new("token", ".net"))))))
    start
  end

  def test_specialtokens_dotnet
    assert_dotnet("zh-hant")
    assert_dotnet("en")
  end

  def assert_dotnet(lang)
    result_set = search("/search/?query=my_str:yahoo.net&language=#{lang}&tracelevel=3&format=xml")
    result_str = result_set.xmldata.to_s

    trace = result_str.lines.grep(/Query time query/)[0]
    query = trace[/my_str:\".+\"/]
    assert_equal("my_str:\"yahoo .net\"", query)
  end

  def teardown
    stop
  end

end
