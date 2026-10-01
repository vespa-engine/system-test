# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'cgi'

# Tests excluding sources with the '-' prefix in model.sources, see VESPANG-3461.
#
# The schema 'music' is in both content clusters, so a document fed to it ends up in both,
# and a query over all sources returns it twice. The schema 'books' is only in cluster2.
class SourcesExclusion < IndexedOnlySearchTest

  def setup
    set_owner("johsol")
    set_description("Test that sources prefixed by '-' in model.sources are excluded from the query, " +
                    "also when YQL selects from all sources")
  end

  def test_sources_exclusion
    cluster1 = SearchCluster.new("cluster1").sd(selfdir + "music.sd")
    cluster2 = SearchCluster.new("cluster2").sd(selfdir + "music.sd").sd(selfdir + "books.sd")
    deploy_files = { selfdir + "app/search/query-profiles/excluding.xml" => "search/query-profiles/excluding.xml" }
    deploy_app(SearchApp.new.cluster(cluster1).cluster(cluster2), :files => deploy_files)
    start

    feed_documents
    wait_for_hitcount("query=sddocname:music", 2)
    wait_for_hitcount("query=sddocname:books", 1)

    check_baseline
    check_cluster_exclusion
    check_exclusion_combined_with_selection
    check_schema_exclusion
    check_unknown_exclusion
    check_exclusion_from_query_profile
  end

  def check_baseline
    # The shared schema gives one hit from each cluster when searching all sources
    assert_sources(music_query, ["cluster1", "cluster2"])
    assert_sources(music_query("cluster1"), ["cluster1"])
    assert_sources(music_query("cluster2"), ["cluster2"])
  end

  def check_cluster_exclusion
    # 'from sources *' in YQL does not override the exclusion
    assert_sources(music_query + "&model.sources=-cluster2", ["cluster1"])
    assert_sources(music_query + "&model.sources=-cluster1", ["cluster2"])
    assert_sources(music_query + "&model.sources=-cluster1,-cluster2", [])

    # Excluded sources are also honored for non-YQL queries
    assert_sources("query=artist:pixies&sources=-cluster2", ["cluster1"])
  end

  def check_exclusion_combined_with_selection
    # Exclusion wins over selection in model.sources
    assert_sources("query=artist:pixies&sources=cluster1,cluster2,-cluster2", ["cluster1"])
    assert_sources("query=artist:pixies&sources=cluster1,-cluster1", [])
    assert_sources(music_query("cluster1") + "&model.sources=-cluster2", ["cluster1"])
    assert_sources(music_query("cluster1") + "&model.sources=cluster2,-cluster1", ["cluster2", "cluster1"])

    # A source named explicitly in YQL overrides its exclusion, also as cluster.schema
    assert_sources(music_query("cluster1") + "&model.sources=-cluster1", ["cluster1"])
    assert_sources(music_query("cluster1.music") + "&model.sources=-cluster1", ["cluster1"])
    assert_sources(music_query("cluster1.music") + "&model.sources=-cluster2", ["cluster1"])
    # ... but the same selection through model.sources does not
    assert_sources("query=artist:pixies&sources=cluster1.music,-cluster1", [])

    # 'from sources *' in YQL replaces the selected sources (as before) but keeps the excluded ones,
    # so this searches all sources except cluster1
    assert_sources(music_query + "&model.sources=cluster1,-cluster1", ["cluster2"])
  end

  def check_schema_exclusion
    all = "yql=" + CGI.escape("select * from sources * where true")
    assert_hitcount(all, 3)
    # Excluding a schema keeps the clusters which have other schemas
    assert_sources(all + "&model.sources=-books", ["cluster1", "cluster2"])
    # cluster1 only has 'music', so it is not searched at all
    assert_sources(all + "&model.sources=-music", ["cluster2"])
    assert_sources(all + "&model.sources=-music,-books", [])
    # Schema exclusion combines with restrict
    assert_sources(all + "&model.restrict=music,books&model.sources=-music", ["cluster2"])
    assert_sources(all + "&model.restrict=music&model.sources=-music", [])
    # Naming the schema in YQL overrides its exclusion
    assert_sources(music_query("music") + "&model.sources=-music", ["cluster1", "cluster2"])
    # A schema can be excluded within one cluster only
    assert_sources(all + "&model.sources=-cluster2.music", ["cluster1", "cluster2"]) # music from cluster1, books from cluster2
    assert_sources(all + "&model.sources=-cluster1.music", ["cluster2", "cluster2"])
    assert_sources(music_query + "&model.sources=-cluster2.music", ["cluster1"])
    # Naming the cluster in YQL does not override the exclusion of one schema within it
    all_in_cluster2 = "yql=" + CGI.escape("select * from sources cluster2 where true")
    assert_sources(all_in_cluster2 + "&model.sources=-cluster2.music", ["cluster2"]) # books only
    assert_sources(music_query("cluster1") + "&model.sources=-cluster1.music", [])
  end

  def check_unknown_exclusion
    # An unknown excluded source gives an error, but the remaining sources are still searched
    query = music_query + "&model.sources=-nonexistent"
    assert_query_errors(query, ["Could not resolve source ref '-nonexistent'"])
    assert_sources(query, ["cluster1", "cluster2"])
  end

  def check_exclusion_from_query_profile
    # The customer scenario: the exclusion is set in a query profile, and the YQL is not under control
    assert_sources(music_query + "&queryProfile=excluding", ["cluster1"])
    assert_sources("query=artist:pixies&queryProfile=excluding", ["cluster1"])
    # Naming both clusters explicitly in YQL overrides the exclusion of cluster2
    assert_sources(music_query("cluster1,cluster2") + "&queryProfile=excluding", ["cluster1", "cluster2"])
    # The query profile value can be overridden in the request
    assert_sources(music_query + "&queryProfile=excluding&model.sources=-cluster1", ["cluster2"])
    # ... and by naming the excluded cluster explicitly in YQL
    assert_sources(music_query("cluster2") + "&queryProfile=excluding", ["cluster2"])
    assert_sources(music_query("cluster2.music") + "&queryProfile=excluding", ["cluster2"])
    assert_sources(music_query("cluster1") + "&queryProfile=excluding", ["cluster1"])
  end

  def music_query(sources = "*")
    "yql=" + CGI.escape("select * from sources #{sources} where artist contains \"pixies\"")
  end

  def assert_sources(query, expected_sources)
    result = search(query + "&trace.level=1")
    actual_sources = result.hit.map { |hit| hit.field["source"] }.sort
    assert_equal(expected_sources.sort, actual_sources,
                 "Query '#{CGI.unescape(query)}' gave hits from #{actual_sources}, expected #{expected_sources}\n" +
                 "Result:\n#{JSON.pretty_generate(result.json)}")
    assert_equal(expected_sources.size, result.hitcount, "Unexpected hit count for query '#{CGI.unescape(query)}'")
  end

  def feed_documents
    vespa.document_api_v1.put(
      Document.new('id:test:music::1').
        add_field('artist', 'Pixies').
        add_field('title', 'Surfer Rosa'))
    vespa.document_api_v1.put(
      Document.new('id:test:books::1').
        add_field('author', 'Frank Herbert').
        add_field('title', 'Dune'))
  end

  def teardown
    stop
  end

end
