# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class NearestNeighborTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_nearest_neighbor_operator
    set_description("Test the nearest neighbor search operator (brute force and over hnsw index)")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search").threads_per_search(1).enable_http_gateway)
    start
    feed_docs

    run_brute_force_tests("pos", "qpos_double")
    run_brute_force_tests("pos", "qpos_float")
    run_hnsw_tests("pos_hnsw", "qpos_double")
  end

  def run_common_tests(doc_tensor, query_tensor)
    assert_nearest_docs(-2, 10, doc_tensor, query_tensor, nil, [[0,2],[1,3],[2,4],[3,5],[4,6],[5,7],[6,8],[7,9],[8,10],[9,11]])
    assert_nearest_docs(-2, 5,  doc_tensor, query_tensor, nil, [[0,2],[1,3],[2,4],[3,5],[4,6]])
    assert_nearest_docs(-2, 3,  doc_tensor, query_tensor, nil, [[0,2],[1,3],[2,4]])
    assert_nearest_docs(-2, 1,  doc_tensor, query_tensor, nil, [[0,2]])
  end

  def run_brute_force_tests(doc_tensor, query_tensor)
    run_common_tests(doc_tensor, query_tensor)

    # In this case we always find a nearer document when evaluating the next,
    # so all documents go through the heap used by the backend search iterator.
    # This means all documents are returned in the result as well.
    assert_nearest_docs(11, 3,  doc_tensor, query_tensor, nil, [[9,2],[8,3],[7,4],[6,5],[5,6],[4,7],[3,8],[2,9],[1,10],[0,11]])

    # With additional query filter
    assert_nearest_docs(-2, 3, doc_tensor, query_tensor, 0, [[0,2],[2,4],[4,6]])
    assert_nearest_docs(-2, 3, doc_tensor, query_tensor, 1, [[1,3],[3,5],[5,7]])
  end

  def run_hnsw_tests(doc_tensor, query_tensor)
    run_common_tests(doc_tensor, query_tensor)

    # This is different from the brute force test as we search the hnsw index and find the top k hits up front and can return only those.
    assert_nearest_docs(11, 3,  doc_tensor, query_tensor, nil, [[9,2],[8,3],[7,4]])
    assert_nearest_docs(7,  1,  doc_tensor, query_tensor, nil, [[7,0]])

    # With additional query filter.
    # HNSW will be used when the iterator is strict (k is less than 5
    # since filter produces 5 hits). HNSW produces 4 hits of which 2 are
    # fitered out:
    assert_nearest_docs(-2, 4, doc_tensor, query_tensor, 0, [[0,2],[2,4]])
    assert_nearest_docs(-2, 4, doc_tensor, query_tensor, 1, [[1,3],[3,5]])
    # Bruteforce is used when iterator is NOT strict:
    assert_nearest_docs(-2, 6, doc_tensor, query_tensor, 0, [[0,2],[2,4],[4,6],[6,8],[8,10]])
    assert_nearest_docs(-2, 6, doc_tensor, query_tensor, 1, [[1,3],[3,5],[5,7],[7,9],[9,11]])
  end

  def get_docid(i)
    "id:test:test::#{i}";
  end

  X_1_POS = 3

  def feed_docs
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change "targetNumHits" and get deterministic behaviour.
    for i in 0...10 do
      doc = Document.new("test", get_docid(i)).
        # TODO: Collapse back to 'pos' when we can choose which algorithm to run in the query.
        add_field("pos", { "values" => [i, X_1_POS] }).
        add_field("pos_hnsw", { "values" => [i, X_1_POS] }).
        add_field("filter", "#{i % 2}")
      vespa.document_api_v1.put(doc)
    end
  end

  def assert_nearest_docs(x_0, target_num_hits, doc_tensor, query_tensor, filter, exp_results)
    query = get_query(x_0, X_1_POS, target_num_hits, doc_tensor, query_tensor, filter)
    puts "assert_nearest_docs(): query='#{query}'"
    result = search(query)
    assert_hitcount(result, exp_results.length)
    for i in 0...exp_results.length do
      exp_docid = exp_results[i][0]
      exp_distance = exp_results[i][1]
      exp_score = 15 - exp_distance
      exp_features = { "rankingExpression(euclidean_distance_#{query_tensor})" => exp_distance,
                       "distance(#{doc_tensor})" => exp_distance,
                       "distance(nns)" => exp_distance }

      assert_field_value(result, "documentid", get_docid(exp_docid), i)
      assert_relevancy(result, exp_score, i)
      assert_features(exp_features, JSON.parse(result.hit[i].field["summaryfeatures"]))
    end
  end

  def get_query(x_0, x_1, target_num_hits, doc_tensor, query_tensor, filter = nil)
    result = "yql=select * from sources * where [{\"targetNumHits\": #{target_num_hits}, \"label\": \"nns\"}] nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += " and filter contains \"#{filter}\"" if filter
    result += ";&ranking.features.query(#{query_tensor})={{x:0}:#{x_0},{x:1}:#{x_1}}"
    return result
  end

  def teardown
    stop
  end
end
