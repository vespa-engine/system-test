# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class RankProfiles < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
  end

  def test_rankprofiles
    set_description("Test use of different rank profiles")
    deploy_app(SearchApp.new.sd(selfdir+"reload1/reload.sd"))
    start
    feed_and_wait_for_docs("reload", 1, :file => selfdir + "reload.json")
    wait_for_hitcount("query=foo&streaming.selection=true", 1)

    # Check that default rankprofile is 'default'
    assert_relevancy("query=foo&streaming.selection=true", 10)
    assert_relevancy("query=foo&ranking=default&streaming.selection=true", 10)

    # Check another profile
    assert_relevancy("query=foo&ranking=first&streaming.selection=true", 20)

    # Check non-existing profile fails
    assert_hitcount("query=foo&ranking=not&streaming.selection=true", 0)
  end

  def test_reload_config
    set_description("Test reload of rank-profiles config")
    deploy_app(SearchApp.new.sd(selfdir+"reload1/reload.sd"))
    start
    #qrserver().logctl("container:com.yahoo.container.di", "debug=on")
    #qrserver().logctl("configproxy:com.yahoo.vespa.config.proxy.ClientUpdater", "debug=on")
    #qrserver().logctl("configproxy:com.yahoo.config.subscription.impl.JRTConfigRequester", "debug=on")
    feed_and_wait_for_docs("reload", 1, :file => selfdir + "reload.json")
    run_reload_config_test_first
    output = deploy_app(SearchApp.new.sd(selfdir+"reload2/reload.sd"))
    wait_for_application(vespa.container.values.first, output)
    run_reload_config_test_second
    output = deploy_app(SearchApp.new.sd(selfdir+"reload1/reload.sd"))
    wait_for_application(vespa.container.values.first, output)
    run_reload_config_test_first
  end

  def test_rank_profiles_extended
    deploy_files = { }
    for file in [ 'schemas/type1/first.profile',
                  'schemas/type1/subdir/default.profile',
                  'schemas/type2/first.profile',
                  'schemas/type2/myvalue.profile' ]
      deploy_files[selfdir + 'app/' + file] = file
    end
    deploy_app(SearchApp.new.cluster_name('test').
                 sd(selfdir + 'app/schemas/type1.sd').
                 sd(selfdir + 'app/schemas/type2.sd'),
               :files => deploy_files)
    start
    feed(:file => selfdir + "documents.json", :cluster => "test")
    wait_for_hitcount("query=sddocname:type1", 1)
    wait_for_hitcount("query=sddocname:type2", 1)

    query1 = "query=field24:document+field24:data&search=type2"
    query2 = "query=field24:document+field24:data&search=type2&ranking=myvalue"
    query3 = "query=document+data"

    # field15 is the only field that is a part of the default index of type1
    query4 = "query=field15:document&search=test&restrict=type1&ranking=field12rank"
    query5 = "query=default:document&search=test&restrict=type1&ranking=field12rank"

    fields = ["relevancy","sddocname","documentid","field11","field12","field13","field14","field21","field22","field23","field24"]

    assert_result(query1, selfdir + "result1.json", nil, fields)
    assert_result(query2, selfdir + "result2.json", nil, fields)
    assert_result(query3, selfdir + "result3.json", nil, fields)
    assert_result(query4, selfdir + "result4.json", nil, fields)

    sf1 = {"attribute(field23)" => 23, "fieldMatch(field24).matches" => 2, "firstPhase" => 230, "query(myvalue)" => 0}
    sf2 = {"attribute(field23)" => 23, "fieldMatch(field24).matches" => 2, "firstPhase" => 235, "query(myvalue)" => 5}

    sf3 = {"attribute(field23)" => 23, "fieldMatch(field24).matches" => 2, "firstPhase" => 230, "query(myvalue)" => 0}
    sf4 = {"attribute(field13)" => 13}

    sf5 = {"attribute(field12)" => 12}

    assert_expression(sf1, query1, 0)
    assert_expression(sf2, query2, 0)
    assert_expression(sf3, query3, 0)
    assert_expression(sf4, query3, 1)

    assert_expression(sf5, query4, 0)
    assert_expression(sf5, query5, 0)
  end

  def run_reload_config_test_first
    wait_for_hitcount("query=sddocname:reload&streaming.selection=true", 1)
    query = "query=foo&streaming.selection=true&nocache&ranking="
    wait_for_relevancy(query + "default", 10)
    wait_for_relevancy(query + "first",   20)
    assert_hitcount(query + "second",  0) # 'second' does not exist, should fail
  end

  def run_reload_config_test_second
    wait_for_hitcount("query=sddocname:reload&streaming.selection=true", 1)
    query = "query=foo&streaming.selection=true&nocache&ranking="
    wait_for_relevancy(query + "default", 11)
    wait_for_relevancy(query + "first",   21)
    wait_for_relevancy(query + "second",  30)
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def assert_expression(exp, query, docid)
    assert_features(exp, search(query).hit[docid].field['summaryfeatures'], 1e-04)
  end

  def teardown
    stop
  end

end
