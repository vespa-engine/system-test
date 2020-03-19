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

    run_brute_force_tests({:query_tensor => "qpos_double"})
    run_brute_force_tests({:query_tensor => "qpos_float"})
    run_hnsw_tests({:query_tensor => "qpos_double"})
  end

  def run_common_tests(query_props)
    query_props[:x_0] = -2
    assert_nearest_docs(query_props, 10, [[0,2],[1,3],[2,4],[3,5],[4,6],[5,7],[6,8],[7,9],[8,10],[9,11]])
    assert_nearest_docs(query_props,  5, [[0,2],[1,3],[2,4],[3,5],[4,6]])
    assert_nearest_docs(query_props,  3, [[0,2],[1,3],[2,4]])
    assert_nearest_docs(query_props,  1, [[0,2]])
  end

  def run_brute_force_tests(query_props)
    query_props[:approx] = "false"
    run_common_tests(query_props)

    # In this case we always find a nearer document when evaluating the next,
    # so all documents go through the heap used by the backend search iterator.
    # This means all documents are returned in the result as well.
    assert_nearest_docs(query_props, 3, [[9,2],[8,3],[7,4],[6,5],[5,6],[4,7],[3,8],[2,9],[1,10],[0,11]], {:x_0 => 11})

    # With additional query filter
    assert_nearest_docs(query_props, 3, [[0,2],[2,4],[4,6]], {:x_0 => -2, :filter => "0"})
    assert_nearest_docs(query_props, 3, [[1,3],[3,5],[5,7]], {:x_0 => -2, :filter => "1"})
  end

  def run_hnsw_tests(query_props)
    run_common_tests(query_props)
    query_props[:approx] = "true"
    run_common_tests(query_props)

    # This is different from the brute force test as we search the hnsw index and find the top k hits up front and can return only those.
    assert_nearest_docs(query_props, 3, [[9,2],[8,3],[7,4]], {:x_0 => 11})
    assert_nearest_docs(query_props, 1, [[7,0]], {:x_0 => 7})

    # With additional query filter.
    # HNSW will be used when the iterator is strict (k is less than 5
    # since filter produces 5 hits). HNSW produces 4 hits of which 2 are
    # fitered out:
    query_props[:x_0] = -2
    assert_nearest_docs(query_props, 4, [[0,2],[2,4]], {:filter => "0"})
    assert_nearest_docs(query_props, 4, [[1,3],[3,5]], {:filter => "1"})
    # Bruteforce is used always when iterator is NOT strict:
    assert_nearest_docs(query_props, 6, [[0,2],[2,4],[4,6],[6,8],[8,10]], {:filter => "0"})
    assert_nearest_docs(query_props, 6, [[1,3],[3,5],[5,7],[7,9],[9,11]], {:filter => "1"})

    # with OR query
    c2 = 1.0 / (1.0 + 2)
    s2 = 10.0 / (1.0 + 2)
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[6,0,0.2]], {:text => "6", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[7,0,0.2]], {:text => "7", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[8,0,0.2]], {:text => "8", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[9,0,0.2]], {:text => "9", :combined => true})

    assert_nearest_docs(query_props, 1, [[0,c2,s2+1],[5,0,0.8]], {:text => "0", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[1,0,0.8],[6,0,0.6]], {:text => "1", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,c2,s2],[2,0,0.6],[7,0,0.4]], {:text => "2", :combined => true})

    assert_nearest_docs(query_props, 1, [[7,0,0.2],[0,0.01,0.1]], {:text => "7", :combined => true, :x_0 => -99})
  end

  def get_docid(i)
    "id:test:test::#{i}";
  end

  X_1_POS = 3

  def feed_docs
    # text field for 10 documents:
    txt = [ "0 x x x 0", "x 1 x x 1", "x x 2 x 2", "x x x 3 3", " 4 x x x 4",
            "x 0 x x 5", "x x 1 x 6", "x x x 2 7", "3 x x x 8", " x 4 x x 9" ]
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change "targetNumHits" and get deterministic behaviour.
    for i in 0...10 do
      doc = Document.new("test", get_docid(i)).
        # TODO: Collapse back to 'pos' when we can choose which algorithm to run in the query.
        add_field("pos", { "values" => [i, X_1_POS] }).
        add_field("text", txt[i]).
        add_field("filter", "#{i % 2}")
      vespa.document_api_v1.put(doc)
    end
  end

  def assert_nearest_docs(setup, target_num_hits, exp_results, overrides = {})
    query_props = setup.merge(overrides)
    query_props[:target_num_hits] = target_num_hits
    query_props[:query_tensor] ||= 'qpos_double'
    query_props[:doc_tensor] ||= 'pos'
    query = get_query(query_props)
    puts "assert_nearest_docs(): query='#{query}'"
    result = search(query)
    assert_hitcount(result, exp_results.length)
    for i in 0...exp_results.length do
      assert_single_doc(exp_results[i], result, i, query_props)
    end
  end

  def assert_single_doc(exp_result, result, i, qp)
    query_tensor = qp[:query_tensor]
    doc_tensor = qp[:doc_tensor]
    exp_docid = exp_result[0]
    if qp[:combined]
      exp_closeness = exp_result[1]
      exp_score = exp_result[2]
      exp_features = { "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_closeness,
                       "itemRawScore(nns)" => exp_closeness }
    else
      exp_distance = exp_result[1]
      exp_score = 15 - exp_distance
      exp_closeness = 1.0 / (1.0 + exp_distance)
      exp_features = { "rankingExpression(euclidean_distance_#{query_tensor})" => exp_distance,
                       "distance(#{doc_tensor})" => exp_distance,
                       "distance(label,nns)" => exp_distance,
                       "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_closeness,
                       "itemRawScore(nns)" => exp_closeness }
    end
    assert_field_value(result, "documentid", get_docid(exp_docid), i)
    assert_relevancy(result, exp_score, i)
    assert_features(exp_features, JSON.parse(result.hit[i].field["summaryfeatures"]))
  end

  def get_query(qprops)
    x_0 = qprops[:x_0] || 0
    x_1 = qprops[:x_1] || X_1_POS
    target_num_hits = qprops[:target_num_hits] || 10
    query_tensor = qprops[:query_tensor]
    doc_tensor = qprops[:doc_tensor]
    approx = qprops[:approx]
    filter = qprops[:filter]
    text = qprops[:text]

    result = "yql=select * from sources * where [{\"targetNumHits\": #{target_num_hits},"
    result += "\"approximate\": #{approx}," if approx
    result += "\"label\": \"nns\"}] nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += " and filter contains \"#{filter}\"" if filter
    result += " or text contains \"#{text}\"" if text
    result += ";&ranking.features.query(#{query_tensor})={{x:0}:#{x_0},{x:1}:#{x_1}}"
    result += "&ranking.profile=combined" if qprops[:combined]
    return result
  end

  def teardown
    stop
  end
end
