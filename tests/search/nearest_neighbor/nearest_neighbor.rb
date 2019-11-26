# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class NearestNeighborTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_brute_force_operator
    set_description("Test the brute force nearest neighbor search operator")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search").threads_per_search(1).enable_http_gateway)
    start
    feed_docs

    assert_nearest_docs(-2, 10, nil, [[0,2],[1,3],[2,4],[3,5],[4,6],[5,7],[6,8],[7,9],[8,10],[9,11]])
    assert_nearest_docs(-2, 5,  nil, [[0,2],[1,3],[2,4],[3,5],[4,6]])
    assert_nearest_docs(-2, 3,  nil, [[0,2],[1,3],[2,4]])
    assert_nearest_docs(-2, 1,  nil, [[0,2]])
    # In this case we always find a nearer document when evaluating the next,
    # so all documents go through the heap used by the backend search iterator.
    # This means all documents are returned in the result as well.
    assert_nearest_docs(11, 3,  nil, [[9,2],[8,3],[7,4],[6,5],[5,6],[4,7],[3,8],[2,9],[1,10],[0,11]])

    # With additional query filter
    assert_nearest_docs(-2, 3, 0, [[0,2],[2,4],[4,6]])
    assert_nearest_docs(-2, 3, 1, [[1,3],[3,5],[5,7]])
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
        add_field("pos", { "values" => [i, X_1_POS] }).
        add_field("filter", "#{i % 2}")
      vespa.document_api_v1.put(doc)
    end
  end

  def assert_nearest_docs(x_0, target_num_hits, filter, exp_results)
    query = get_query(x_0, X_1_POS, target_num_hits, filter)
    puts "assert_nearest_docs(): query='#{query}'"
    result = search(query)
    assert_hitcount(result, exp_results.length)
    for i in 0...exp_results.length do
      exp_docid = exp_results[i][0]
      exp_distance = exp_results[i][1]
      exp_score = 15 - exp_distance
      exp_features = { "rankingExpression(euclidean_distance)" => exp_distance,
                       "rankingExpression(raw_score)" => exp_distance }

      assert_field_value(result, "documentid", get_docid(exp_docid), i)
      assert_relevancy(result, exp_score, i)
      assert_features(exp_features, JSON.parse(result.hit[i].field["summaryfeatures"]))
    end
  end

  def get_query(x_0, x_1, target_num_hits, filter = nil)
    result = "yql=select * from sources * where [{\"targetNumHits\": #{target_num_hits}}] nearestNeighbor(pos,qpos)"
    result += " and filter contains \"#{filter}\"" if filter
    result += ";&ranking.features.query(qpos)={{x:0}:#{x_0},{x:1}:#{x_1}}"
    return result
  end

  def teardown
    stop
  end
end
