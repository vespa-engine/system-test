# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'
require 'environment'

class MapTypeTest < StreamingSearchTest

  def timeout_seconds
    3600
  end

  def get_query(query)
    return "query=" + query + "&streaming.userid=1&searchChain=maptestchain"
  end

  def get_app
    SearchApp.new.streaming.provider("PROTON").
      container(Container.new().
                search(Searching.new.
                    chain(Chain.new("maptestchain").inherits("vespa").
                          add(Searcher.new("com.yahoo.prelude.searcher.JSONDebugSearcher")))).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      config(ConfigOverride.new("vespa.config.search.core.proton").
             add("summary", ConfigValue.new("cache", ConfigValue.new("allowvisitcaching", "true"))).
             add("summary", ConfigValue.new("cache", ConfigValue.new("maxbytes", "10000000"))))
  end

  def test_map_update
    set_owner("balder")
    deploy_app(get_app.sd(selfdir + "schemas/mapupdatetest.sd"))
    start
    feedfile(selfdir+"feedmapupdate.xml")
    wait_for_hitcount(get_query("sddocname:mapupdatetest"), 1)
    http = https_client.create_client(vespa.document_api_v1.host, Environment.instance.vespa_web_service_port)
    http.read_timeout=190
    httpheaders={}
    response = http.get("/document/v1/mapupdatetest/mapupdatetest/number/1/0")
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"fields\":{\"tagset\":{\"balder\":1,\"bergum\":2},\"name\":\"id0\"},\"id\":\"id:mapupdatetest:mapupdatetest:n=1:0\",\"pathId\":\"/document/v1/mapupdatetest/mapupdatetest/number/1/0\"}",
      response.body)

    feedfile(selfdir+"updatemapupdate.json")

    response = http.get("/document/v1/mapupdatetest/mapupdatetest/number/1/0")
    assert_equal("200", response.code)
    assert_json_string_equal(
      "{\"fields\":{\"tagset\":{\"balder\":1,\"britney\":1,\"bergum\":2},\"name\":\"id0\"},\"id\":\"id:mapupdatetest:mapupdatetest:n=1:0\",\"pathId\":\"/document/v1/mapupdatetest/mapupdatetest/number/1/0\"}",
      response.body)

  end

  def test_map
    set_owner("balder")
    set_description("Test for streaming search in map type")
    deploy_app(get_app.sd(selfdir + "schemas/maptest.sd"))
    start
    feedfile(selfdir+"feedmap.xml")
    wait_for_hitcount(get_query("sddocname:maptest"), 2)

    puts "Test grouping"
    q = get_query("sddocname:maptest&hits=0&select=all%28group%28m1.key%29 each%28output%28count%28%29%29%29%29")
    # save_result(q, selfdir + 'res-grp-1.json')
    assert_result(q, selfdir + 'res-grp-1.json')
    q = get_query("sddocname:maptest&hits=0&select=all%28group%28m1.value%29 each%28output%28count%28%29%29%29%29")
    # save_result(q, selfdir + 'res-grp-2.json')
    assert_result(q, selfdir + 'res-grp-2.json')
    q = get_query("sddocname:maptest&hits=0&select=all%28group%28attribute%28m1%7Bk1%7D%29%29 each%28output%28count%28%29%29%29%29")
    # save_result(q, selfdir + 'res-grp-3.json')
    assert_result(q, selfdir + 'res-grp-3.json')

    puts "Test query (map<string, string>)"
    assert_hitcount(get_query("m1:k0"),  2)
    assert_hitcount(get_query("m1:v11"), 1)
    assert_hitcount(get_query("m1:m1"),  2)
    assert_hitcount(get_query("m1:not"), 0)
    assert_hitcount(get_query("m1.key:k0"),  2)
    assert_hitcount(get_query("m1.key:v11"), 0)
    assert_hitcount(get_query("m1.key:m1"),  0)
    assert_hitcount(get_query("m1.value:k0"),  0)
    assert_hitcount(get_query("m1.value:v11"), 1)
    assert_hitcount(get_query("m1.value:m1"),  2)
    assert_hitcount(get_query("v00&default-index=m1%7Bk0%7D"), 1)
    assert_hitcount(get_query("v11&default-index=m1%7Bk0%7D"), 0)
    assert_hitcount(get_query("p0&default-index=m1.value"), 2)
    assert_hitcount(get_query("p0&default-index=m1%7Bk0%7D"),   1)

    puts "Test query (map<string, struct>)"
    assert_hitcount(get_query("m2:k0"),  2)
    assert_hitcount(get_query("m2:a00"), 1)
    assert_hitcount(get_query("m2:b11"), 1)
    assert_hitcount(get_query("m2:m2"),  2)
    assert_hitcount(get_query("m2:not"), 0)
    assert_hitcount(get_query("m2.value:k0"),  0)
    assert_hitcount(get_query("m2.value:a00"), 1)
    assert_hitcount(get_query("m2.value:b11"), 1)
    assert_hitcount(get_query("m2.value:m2"),  2)
    assert_hitcount(get_query("a00&default-index=m2.value.a"), 1)
    assert_hitcount(get_query("a00&default-index=m2.value.b"), 0)
    assert_hitcount(get_query("p0&default-index=m2.value.a"), 2)
    assert_hitcount(get_query("p0&default-index=m2%7Bk0%7D.a"),   1)

    puts "Test query (map<string, array>)"
    assert_hitcount(get_query("m3:k0"),   2)
    assert_hitcount(get_query("m3:i000"), 1)
    assert_hitcount(get_query("m3:i111"), 1)
    assert_hitcount(get_query("m3:m3"),   2)
    assert_hitcount(get_query("m3:not"),  0)
    assert_hitcount(get_query("m3.value:k0"),   0)
    assert_hitcount(get_query("m3.value:i000"), 1)
    assert_hitcount(get_query("m3.value:i111"), 1)
    assert_hitcount(get_query("m3.value:m3"),   2)
    assert_hitcount(get_query("p0&default-index=m3.value"), 2)
    assert_hitcount(get_query("p0&default-index=m3%7Bk0%7D"),   1)

    puts "Test query (map<string, map<string, string>>)"
    assert_hitcount(get_query("m4:k0"),  2)
    assert_hitcount(get_query("m4:v00"), 1)
    assert_hitcount(get_query("m4:v11"), 1)
    assert_hitcount(get_query("m4:m4"),  2)
    assert_hitcount(get_query("m4:k00"), 2)
    assert_hitcount(get_query("m4:not"), 0)
    assert_hitcount(get_query("m4.value:k0"),  0)
    assert_hitcount(get_query("m4.value:k00"), 2)
    assert_hitcount(get_query("m4.value:v00"), 1)
    assert_hitcount(get_query("m4.value:v11"), 1)
    assert_hitcount(get_query("m4.value:m4"),  2)
    assert_hitcount(get_query("k00&default-index=m4.value.key"),   2)
    assert_hitcount(get_query("k00&default-index=m4.value.value"), 0)
    assert_hitcount(get_query("v00&default-index=m4.value.value"), 1)
    assert_hitcount(get_query("v11&default-index=m4.value.value"), 1)
    assert_hitcount(get_query("m4&default-index=m4.value.value"),  2)
    assert_hitcount(get_query("p0&default-index=m4.value"), 2)
    assert_hitcount(get_query("p0&default-index=m4%7Bk0%7D"),   1)
    assert_hitcount(get_query("p0&default-index=m4.value.value"), 2)
    assert_hitcount(get_query("p0&default-index=m4.value%7Bk00%7D"),  1)
    assert_hitcount(get_query("q0&default-index=m4%7Bk0%7D.value"), 2)
    assert_hitcount(get_query("q0&default-index=m4%7Bk0%7D%7Bk00%7D"),  1)

    puts "Test summary"
    # save_result(get_query("name:id0"), selfdir + "maptest.result")
    assert_result(get_query("name:id0"), selfdir + "maptest.result", nil, ["m1", "m2", "m3", "m4"])

    npos = 1000000
    puts "Test summary features (map<string, string>)"
    assert_sf("m1:k1", "m1.key", 0, 1, 1)
    assert_sf("m1:m1", "m1.key", npos, 0, npos)
    assert_sf("m1:k1", "m1.value", npos, 0, npos)
    assert_sf("m1:m1", "m1.value", 0, 2, 3)
    assert_sf("m1:v00", "m1.value", 1, 1, 3)
    assert_sf("m1&default-index=m1%7Bk0%7D", "m1.value", 0, 1, 3)

    puts "Test summary features (map<string, struct>)"
    assert_sf("m2:m2", "m2.value.a", 0, 2, 3)
    assert_sf("m2:a01", "m2.value.a", 1, 1, 3)
    assert_sf("m2&default-index=m2%7Bk0%7D", "m2.value.a", 0, 1, 3)
    assert_sf("m2&default-index=m2.value.a", "m2.value.a", 0, 2, 3)
    assert_sf("m2&default-index=m2%7Bk0%7D.a", "m2.value.a", 0, 1, 3)

    puts "Test summary features (map<string, array<string>>)"
    assert_sf("m3:m3", "m3.value", 0, 4, 3)
    assert_sf("m3:i010", "m3.value", 1, 1, 3)
    assert_sf("m3&default-index=m3%7Bk0%7D", "m3.value", 0, 2, 3)

    puts "Test summary features (map<string, map<string, string>>)"
    assert_sf("m4:m4", "m4.value.value", 0, 2, 4)
    assert_sf("m4:v01", "m4.value.value", 1, 1, 3)
    assert_sf("m4:q1", "m4.value.value", 0, 1, 1)
    assert_sf("m4&default-index=m4.value", "m4.value.value", 0, 2, 4)
    assert_sf("m4&default-index=m4.value.value", "m4.value.value", 0, 2, 4)
    assert_sf("m4&default-index=m4.value%7Bk00%7D", "m4.value.value", 0, 1, 4)
    assert_sf("m4&default-index=m4%7Bk0%7D", "m4.value.value", 0, 1, 4)
    assert_sf("m4&default-index=m4%7Bk0%7D.value", "m4.value.value", 0, 1, 4)
    assert_sf("m4&default-index=m4%7Bk0%7D%7Bk00%7D", "m4.value.value", 0, 1, 4)
  end

  def assert_sf(query, fname, fpos, occs, flength)
    result = search(get_query(query+"&filter=-name:id1"))
    exp = {"fieldTermMatch(#{fname},0).occurrences" => occs, \
           "fieldLength(#{fname})" => flength}
    assert_equal(1, result.hit.size)
    assert_equal("id0", result.hit[0].field["name"])
    assert_features(exp, result.hit[0].field["summaryfeatures"], 1e-4)
  end

  def get_default_log_check_levels
    return [:warning, :error, :fatal]
  end

  def teardown
    stop
  end


end
