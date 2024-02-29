# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class ApproximateNearestNeighborWithFilterTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def test_ann_with_filters
    set_description("Test approximate nearest neighbor search with filters and tuning of strategies (pre- vs post-filter)")
    deploy_app(SearchApp.new.sd(selfdir + "ann_with_filter/test.sd").threads_per_search(1).enable_document_api)
    start
    feed_docs

    # Only searching the HNSW graph:
    assert_docs_and_setup([6, 7, 5],
                          ["Calculate global filter (estimated_hit_ratio (1.000000) <= upper_limit (1.000000))",
                           "Global filter matches everything",
                           "Handle global filter in query execution plan"],
                           get_query({:qpos => 62, :trace => true}))

    # Searching the HNSW graph using the result from pre-filter execution:
    assert_docs_and_setup([5, 4, 3],
                          ["Calculate global filter (estimated_hit_ratio (0.500000) <= upper_limit (1.000000))",
                           "Handle global filter in query execution plan"],
                           get_query({:qpos => 62, :tag => 5, :trace => true}))

    # Fallback to exact nearest neighbor search (estimated-hit-ratio < approximate-threshold):
    assert_docs([5, 4, 3, 2, 1],
                get_query({:qpos => 62, :tag => 5, :ranking => "exact_search"}))
    assert_docs([5, 4, 3, 2, 1],
                get_query({:qpos => 62, :tag => 5, :approximate => 0.51}))
    assert_docs([5, 4, 3],
                get_query({:qpos => 62, :tag => 5, :approximate => 0.5})) # default pre-filtering

    # Using post-filtering where the HNSW graph is searched first (estimated-hit-ratio > post-filter-threshold):
    # With qpos => 82, the closest documents are: 8, 9, 7, 6, 5, 4, ...
    # Note that adjusted targetHits = (targetHits / estimated-hit-ratio) when using post-filtering:
    # tag => 6: (3 / 0.6) = 5
    # tag => 7: (3 / 0.7) = 4
    # tag => 8: (3 / 0.8) = 3
    # tag => 9: (3 / 0.9) = 3
    assert_docs([7, 6],
                get_query({:qpos => 82, :tag => 7, :ranking => "post_filter"}))
    assert_docs([7, 6],
                get_query({:qpos => 82, :tag => 7, :post_filter => 0.69}))
    assert_docs([7, 6, 5],
                get_query({:qpos => 82, :tag => 7, :post_filter => 0.7})) # default pre-filtering
    assert_docs([6, 5],
                get_query({:qpos => 82, :tag => 6, :post_filter => 0.59}))
    assert_docs([8, 7],
                get_query({:qpos => 82, :tag => 8, :post_filter => 0.79}))
    assert_docs([8, 9, 7],
                get_query({:qpos => 82, :tag => 9, :post_filter => 0.89}))
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

  X_1_POS = 30

  def get_docid(docid)
    "id:test:test::#{docid}"
  end

  def feed_doc(docid, pos, tags)
    doc = Document.new("test", get_docid(docid)).
      add_field("pos", { "values" => [pos, X_1_POS] }).
      add_field("tags", tags)
    vespa.document_api_v1.put(doc)
  end

  def get_query(args)
    qpos = args[:qpos]
    target_hits = args[:target_hits] || 3
    tag = args[:tag]
    ranking = args[:ranking] || "default"
    post_filter = args[:post_filter]
    approximate = args[:approximate]
    trace = args[:trace]
    result = "yql=select * from sources * where {targetHits:#{target_hits},approximate:true}nearestNeighbor(pos,qpos)"
    result += " and tags contains '#{tag}'" if tag
    result += "&ranking.features.query(qpos)=[#{qpos},#{X_1_POS}]"
    result += "&ranking.profile=#{ranking}"
    result += "&ranking.matching.postFilterThreshold=#{post_filter}" if post_filter
    result += "&ranking.matching.approximateThreshold=#{approximate}" if approximate
    result += "&trace.level=1&trace.explainLevel=1" if trace
    return result
  end

  def assert_docs(exp_docids, query)
    puts "assert_docs(): exp_docids=#{exp_docids}, query='#{query}'"
    result = search(query)
    puts "result: #{result.json.to_json}"
    assert_hitcount(result, exp_docids.length)
    for i in 0...exp_docids.length do
      assert_field_value(result, "documentid", get_docid(exp_docids[i]), i)
    end
    result
  end

  def assert_docs_and_setup(exp_docids, exp_steps, query)
    result = assert_docs(exp_docids, query)
    assert_query_setup(exp_steps, result)
  end

  def assert_query_setup(exp_steps, result)
    traces = result.json["trace"]["children"][1]["children"][0]["children"][1]["message"][0]["traces"][0]["traces"]
    puts "assert_query_setup(): traces: #{traces}"
    # See ../explain/explain.rb for the first steps in the 'query_setup' trace.
    for i in 0...exp_steps.length do
      assert_equal(exp_steps[i], traces[5 + i]["event"])
    end
  end

  def teardown
    stop
  end
end
