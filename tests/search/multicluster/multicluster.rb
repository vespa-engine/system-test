# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class MultiCluster < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Test searching with 2 content clusters, with one doc type in each, where the 2 doc types has a field with same name, except case")
  end

  def test_2_clusters_2_doc_types_field_name_equal_except_case
    cluster1 = SearchCluster.new("cluster1").sd(selfdir + "music.sd")
    cluster2 = SearchCluster.new("cluster2").sd(selfdir + "music2.sd")
    deploy_app(SearchApp.new.cluster(cluster1).cluster(cluster2))
    start

    feed_music_document
    feed_music2_document

    search_and_assert_hitcount('query=title:Surfer', 1)
    # This fails at the moment, due to (from trace, /opt/vespa/tmp/lastresult.xml):
    # {"message":"Query parsed to: select * from sources cluster1, cluster2 where weakAnd(title contains \"Surfer\") timeout 5000"}
    search_and_assert_hitcount('query=TITLE:Surfer', 0)
    search_and_assert_hitcount('query=title:Dummy', 0)
    search_and_assert_hitcount('query=TITLE:Dummy', 1)
  end

  def feed_music_document
    vespa.document_api_v1.put(
      Document.new('music', 'id:test:music::1').
        add_field("artist", 'Pixies').
        add_field('title', 'Surfer Rosa'))
  end

  def feed_music2_document
    vespa.document_api_v1.put(
      Document.new('music', 'id:test:music2::1').
        add_field("artist", 'Portishead').
        add_field('TITLE', 'Dummy'))
  end

  def search_and_assert_hitcount(query, expected_hit_count)
    query_with_sources = query + "&sources=cluster1,cluster2&trace.level=2"
    assert_hitcount(query_with_sources, expected_hit_count)
  end

  def teardown
    stop
  end

end
