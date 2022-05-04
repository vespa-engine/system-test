# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class ApproximateNearestNeighborWithFilterTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def test_ann_with_filters
    set_description("Test approximate nearest neighbor search with filters and tuning of strategies (pre- vs post-filter)")
    deploy_app(SearchApp.new.sd(selfdir + "ann_with_filter/test.sd").threads_per_search(1).enable_document_api)
    start
    feed_docs

    # Only searching the HNSW graph:
    assert_docs([6, 7, 5],
                get_query({:qpos => 62}))

    # Searching the HNSW graph using the result from pre-filter execution:
    assert_docs([5, 4, 3],
                get_query({:qpos => 62, :tag => 5}))

    # Fallback to exact nearest neighbor search (estimated-hit-ratio < approximate-threshold):
    assert_docs([5, 4, 3, 2, 1],
                get_query({:qpos => 62, :tag => 5, :ranking => "exact_search"}))
    assert_docs([5, 4, 3, 2, 1],
                get_query({:qpos => 62, :tag => 5, :approximate => 0.51}))
    assert_docs([5, 4, 3],
                get_query({:qpos => 62, :tag => 5, :approximate => 0.5})) # default pre-filtering

    # Using post-filtering where the HNSW graph is searched first (estimated-hit-ratio > post-filter-threshold):
    assert_docs([7],
                get_query({:qpos => 82, :tag => 7, :ranking => "post_filter"}))
    assert_docs([7],
                get_query({:qpos => 82, :tag => 7, :post_filter => 0.69}))
    assert_docs([7, 6, 5],
                get_query({:qpos => 82, :tag => 7, :post_filter => 0.7})) # default pre-filtering
    assert_docs([],
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
    tag = args[:tag]
    ranking = args[:ranking] || "default"
    post_filter = args[:post_filter]
    approximate = args[:approximate]
    result = "yql=select * from sources * where {targetHits:3,approximate:true}nearestNeighbor(pos,qpos)"
    result += " and tags contains '#{tag}'" if tag
    result += "&ranking.features.query(qpos)=[#{qpos},#{X_1_POS}]"
    result += "&ranking.profile=#{ranking}"
    result += "&ranking.matching.postFilterThreshold=#{post_filter}" if post_filter
    result += "&ranking.matching.approximateThreshold=#{approximate}" if approximate
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
  end

  def teardown
    stop
  end
end
