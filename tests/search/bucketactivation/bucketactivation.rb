# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class BucketActivationTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def get_query(search_path = nil)
    query = "query=sddocname:music&nocache"
    if (search_path != nil)
      query = query + "&model.searchPath=#{search_path}"
    end
    return query
  end

  def check(search_path = nil)
    query = get_query(search_path)
    wait_for_hitcount(query, 10)
    assert_hitcount(get_query(), 10)
    assert_result(get_query(), SEARCH_DATA+"music.10.result.json", "title", ["title", "surl"])
  end

  def assert_job_metric
    full_name = "content.proton.documentdb.job.bucket_move"
    value = vespa.search["mycluster"].first.get_total_metrics.get(full_name)["average"]
    puts "#{full_name}['average']=#{value}"
    assert(value > 0.0)
  end

  def test_bucket_activation
    set_description("Test basic searching with bucket activation")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
               search_type("ELASTIC").cluster_name("mycluster").num_parts(4).redundancy(2).
               storage(StorageCluster.new("mycluster", 4).distribution_bits(16)))

    start
    vespa.stop_content_node("mycluster", "3")
    vespa.stop_content_node("mycluster", "2")
    vespa.stop_content_node("mycluster", "1")

    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    check("0/0")
    wait_for_hitcount(get_query("1/0"), 0)
    wait_for_hitcount(get_query("2/0"), 0)
    wait_for_hitcount(get_query("3/0"), 0)
    assert_job_metric

    # activate nodes
    start_node_and_wait("mycluster", 1)
    check("0,1/0")
    wait_for_atleast_hitcount(get_query("0/0"), 1)
    wait_for_atleast_hitcount(get_query("1/0"), 1)
    wait_for_hitcount(get_query("2/0"), 0)
    wait_for_hitcount(get_query("3/0"), 0)

    start_node_and_wait("mycluster", 2)
    check("0,1,2/0")
    wait_for_atleast_hitcount(get_query("0/0"), 1)
    wait_for_atleast_hitcount(get_query("1/0"), 1)
    wait_for_atleast_hitcount(get_query("2/0"), 1)
    wait_for_hitcount(get_query("3/0"), 0)

    start_node_and_wait("mycluster", 3)
    check("0,1,2,3/0")
    wait_for_atleast_hitcount(get_query("0/0"), 1)
    wait_for_atleast_hitcount(get_query("1/0"), 1)
    wait_for_atleast_hitcount(get_query("2/0"), 1)
    wait_for_atleast_hitcount(get_query("3/0"), 1)

    # de-activate nodes
    stop_node_and_wait("mycluster", 0)
    check("1,2,3/0")

    stop_node_and_wait("mycluster", 1)
    check("2,3/0")

    stop_node_and_wait("mycluster", 2)
    check("3/0")
  end

  def teardown
    stop
  end

end
