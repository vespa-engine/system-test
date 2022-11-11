# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'json'

class DataMigrationConsistency < IndexedSearchTest

  def setup
    set_owner('havardpe')
    set_description("Test that documents preserve state across data migration")
  end

  def test_data_migration_consistency
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd').cluster_name("mycluster").num_parts(2).redundancy(2))
    start
    stop_node_and_wait("mycluster", 1)
    feed_and_wait_for_docs('test', 3, :file => selfdir + 'docs.json')
    start_node_and_wait("mycluster", 1)
    stop_node_and_wait("mycluster", 0)
    verify_doc(search("/search/?query=title:doc1&format=json&hits=10&type=all").json, "doc1")
    verify_doc(search("/search/?query=title:doc2&format=json&hits=10&type=all").json, "doc2")
    verify_doc(search("/search/?query=title:doc3&format=json&hits=10&type=all").json, "doc3")
  end

  def verify_doc(result, expected_title)
    puts "result=#{JSON.pretty_generate(result)}"
    assert_equal(1, result["root"]["children"].size);
    assert_equal(expected_title, result["root"]["children"][0]["fields"]["title"]);
    assert_equal(expected_title, result["root"]["children"][0]["fields"]["ext_title"]);
  end

  def teardown
    stop
  end
end
