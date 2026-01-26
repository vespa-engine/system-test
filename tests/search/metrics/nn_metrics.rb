# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class NNSMatchingMetrics < IndexedOnlySearchTest
  def setup
    set_owner("boeker")
  end

  def test_nns_matching_metrics
    set_description("Test reporting of matching metrics specific for nearest neighbor search")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').sd(selfdir + "nn_metrics/test.sd")))
    start
    feed_docs

    # No queries yet
    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(0, enn_distances)
    assert_equal(0, ann_distances)
    assert_equal(0, ann_visited)

    ####################################################################################################################
    puts "HNSW search without filtering"
    ####################################################################################################################
    run_query(get_query({:qpos => 62}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 9)
    assert(ann_visited >= 9)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "default")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 9)
    assert(ann_visited >= 9)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW

    ####################################################################################################################
    puts "HNSW search with filtering"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :tag => 5}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 18)
    assert(ann_visited >= 18)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "default")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 18)
    assert(ann_visited >= 18)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW

    saved_ann_distances = ann_distances
    saved_ann_visited = ann_visited

    ####################################################################################################################
    puts "Exact search"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :approximate => "false"}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(9, enn_distances)
    assert_equal(saved_ann_distances, ann_distances)
    assert_equal(saved_ann_visited, ann_visited)
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "default")
    assert_equal(9, enn_distances)
    assert_equal(saved_ann_distances, ann_distances)
    assert_equal(saved_ann_visited, ann_visited)

    ####################################################################################################################
    puts "Exact search with filtering"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :tag => 5, :approximate => "false"}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(14, enn_distances)
    assert_equal(saved_ann_distances, ann_distances)
    assert_equal(saved_ann_visited, ann_visited)
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "default")
    assert_equal(14, enn_distances)
    assert_equal(saved_ann_distances, ann_distances)
    assert_equal(saved_ann_visited, ann_visited)

    ####################################################################################################################
    puts "Exact search with filtering (fallback)"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :tag => 5, :ranking => "exact_fallback"}))

    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "exact_fallback")
    assert_equal(5, enn_distances)
    assert_equal(0, ann_distances)
    assert_equal(0, ann_visited)

    ####################################################################################################################
    puts "HNSW with post-filter"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :tag => 5, :ranking => "post_filter"}))

    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "post_filter")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 9)
    assert(ann_visited >= 9)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW

    ####################################################################################################################
    puts "HSNW with filter first"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :tag => 5, :ranking => "filter_first"}))

    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("test", "filter_first")
    assert_equal(0, enn_distances)
    assert(ann_distances >= 5)
    assert(ann_visited >= 9)

    ####################################################################################################################
    puts "Verifying overall metrics again"
    ####################################################################################################################

    enn_distances, ann_distances, ann_visited = get_metrics("test")
    assert_equal(enn_distances, 19)
    assert(ann_distances >= 32)
    assert(ann_visited >= 36)
  end

  def test_nns_matching_metrics_multiple_vectors
    set_description("Test reporting of matching metrics specific for nearest neighbor search for multi-vector indexing")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('multi').sd(selfdir + "nn_metrics/multi.sd")))
    start

    vector0 = [{'address'=>{'m'=>'a', 'x'=>'0'}, 'value'=>1.0},
               {'address'=>{'m'=>'a', 'x'=>'1'}, 'value'=>1.0},
               {'address'=>{'m'=>'b', 'x'=>'0'}, 'value'=>2.0},
               {'address'=>{'m'=>'b', 'x'=>'1'}, 'value'=>2.0}]
    vector1 = [{'address'=>{'m'=>'a', 'x'=>'0'}, 'value'=>3.0},
               {'address'=>{'m'=>'a', 'x'=>'1'}, 'value'=>3.0},
               {'address'=>{'m'=>'b', 'x'=>'0'}, 'value'=>4.0},
               {'address'=>{'m'=>'b', 'x'=>'1'}, 'value'=>4.0},
               {'address'=>{'m'=>'c', 'x'=>'0'}, 'value'=>5.0},
               {'address'=>{'m'=>'c', 'x'=>'1'}, 'value'=>5.0}]

    doc0 = Document.new("id:multi:multi::0").add_field("pos", vector0)
    doc1 = Document.new("id:multi:multi::1").add_field("pos", vector1)
    vespa.document_api_v1.put(doc0)
    vespa.document_api_v1.put(doc1)

    # No queries yet
    enn_distances, ann_distances, ann_visited = get_metrics("multi")
    assert_equal(0, enn_distances)
    assert_equal(0, ann_distances)
    assert_equal(0, ann_visited)

    ####################################################################################################################
    puts "Exact search"
    ####################################################################################################################
    run_query(get_query({:qpos => 80, :approximate => "false"}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("multi")
    assert_equal(5, enn_distances)
    assert_equal(0, ann_distances)
    assert_equal(0, ann_visited)
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("multi", "default")
    assert_equal(5, enn_distances)
    assert_equal(0, ann_distances)
    assert_equal(0, ann_visited)

    ####################################################################################################################
    puts "HNSW search without filtering"
    ####################################################################################################################
    run_query(get_query({:qpos => 62}))

    # Verify overall metrics
    enn_distances, ann_distances, ann_visited = get_metrics("multi")
    assert_equal(5, enn_distances)
    assert(ann_distances >= 5)
    assert(ann_visited >= 5)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW
    # Verify rank-profile metrics
    enn_distances, ann_distances, ann_visited = get_rp_metrics("multi", "default")
    assert_equal(5, enn_distances)
    assert(ann_distances >= 5)
    assert(ann_visited >= 5)
    assert_equal(ann_distances, ann_visited) # Always the same for plain HNSW
  end

  def get_metrics(doc_name)
    metrics = vespa.search[doc_name].first.get_total_metrics
    extract_metrics(metrics, doc_name)
  end

  def extract_metrics(metrics, doc_name)
    enn_distances = extract_metric(metrics, doc_name, "exact_nns_distances_computed")
    ann_distances = extract_metric(metrics, doc_name, "approximate_nns_distances_computed")
    ann_visited = extract_metric(metrics, doc_name, "approximate_nns_nodes_visited")
    return enn_distances, ann_distances, ann_visited
  end

  def extract_metric(metrics, doc_name, name)
    value = metrics.get("content.proton.documentdb.matching.#{name}", {"documenttype" => doc_name})["count"]
    puts "content.proton.documentdb.matching.#{name} = #{value}"
    value
  end

  def get_rp_metrics(doc_name, rank_profile)
    metrics = vespa.search[doc_name].first.get_total_metrics
    extract_rp_metrics(metrics, doc_name, rank_profile)
  end

  def extract_rp_metrics(metrics, doc_name, rank_profile)
    enn_distances = extract_rp_metric(metrics, doc_name, rank_profile, "exact_nns_distances_computed")
    ann_distances = extract_rp_metric(metrics, doc_name, rank_profile, "approximate_nns_distances_computed")
    ann_visited = extract_rp_metric(metrics, doc_name, rank_profile, "approximate_nns_nodes_visited")
    return enn_distances, ann_distances, ann_visited
  end

  def extract_rp_metric(metrics, doc_name, rank_profile, name)
    value = metrics.get("content.proton.documentdb.matching.rank_profile.#{name}", {"documenttype" => doc_name, "rankProfile" => rank_profile})["count"]
    puts "content.proton.documentdb.matching.rank_profile.#{name} = #{value} for rank profile #{rank_profile}"
    value
  end

  def feed_docs
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This is necessary to get deterministic behavior when fallbacking to exact nearest neighbor search,
    # and documents are evaluated in order.

    # This feeds 9 documents that are placed along a line in 2D space.
    # The tags array is used to limit the number of documents returned when searching a given tag.
    # E.g. tag '6' returns 6 documents, with an estimated-hit-ratio of 0.6 (6 / (9 + 1)).
    feed_doc(1, 10, [9, 8, 7, 6, 5, 4, 3, 2, 1])
    feed_doc(2, 20, [9, 8, 7, 6, 5, 4, 3, 2])
    feed_doc(3, 30, [9, 8, 7, 6, 5, 4, 3])
    feed_doc(4, 40, [9, 8, 7, 6, 5, 4])
    feed_doc(5, 50, [9, 8, 7, 6, 5])
    feed_doc(6, 60, [9, 8, 7, 6])
    feed_doc(7, 70, [9, 8, 7])
    feed_doc(8, 80, [9, 8])
    feed_doc(9, 90, [9])
  end

  def feed_doc(docid, pos, tags)
    doc = Document.new("id:test:test::#{docid}").
      add_field("pos", { "values" => [pos, 30] }).
      add_field("tags", tags)
    vespa.document_api_v1.put(doc)
  end

  def get_query(args)
    qpos = args[:qpos]
    target_hits = args[:target_hits] || 100
    tag = args[:tag]
    ranking = args[:ranking] || "default"
    approximate = args[:approximate] || "true"
    trace = args[:trace]
    result = "yql=select * from sources * where {targetHits:#{target_hits},approximate:#{approximate}}nearestNeighbor(pos,qpos)"
    result += " and tags contains '#{tag}'" if tag
    result += "&ranking.features.query(qpos)=[#{qpos},30]"
    result += "&ranking.profile=#{ranking}"
    result += "&trace.level=1&trace.explainLevel=1" if trace
    return result
  end

  def run_query(query)
    puts "query: '#{query}'"
    search(query)
  end

end
