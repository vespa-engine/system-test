# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class NearestNeighborTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_nearest_neighbor_operator
    set_description("Test the nearest neighbor search operator (brute force and over hnsw index)")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").threads_per_search(1).enable_document_api)
    start
    feed_docs

    run_all_tests
    assert_flushing_of_hnsw_index
    restart_proton("test", 10)
    run_all_tests

    feed_docs
    run_all_tests

    feed_docs(false)
    feed_assign_updates
    run_all_tests
  end

  def test_nns_via_parent
    set_description('Test the nearest neighbor search operator with imported attribute')
    deploy_app(SearchApp.new
                 .sd(selfdir + 'campaign.sd', { :global => true })
                 .sd(selfdir + 'ad.sd')
                 .threads_per_search(1)
                 .enable_document_api)
    start
    feed_campaign_docs
    feed_ad_docs
    run_brute_force_tests({:query_tensor => 'qpos_double', :doc_type => 'ad'})
  end

  def run_all_tests
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

  def run_common_and_query_tests(query_props)
    # Using AND query filter
    query_props[:x_0] = -2
    assert_nearest_docs(query_props, 1, [[0,2]], {:filter => "0"})
    assert_nearest_docs(query_props, 1, [[1,3]], {:filter => "1"})
    assert_nearest_docs(query_props, 2, [[0,2],[2,4]], {:filter => "0"})
    assert_nearest_docs(query_props, 2, [[1,3],[3,5]], {:filter => "1"})
    assert_nearest_docs(query_props, 3, [[0,2],[2,4],[4,6]], {:filter => "0"})
    assert_nearest_docs(query_props, 3, [[1,3],[3,5],[5,7]], {:filter => "1"})
    # Asking for k=6, but only 5 hits available
    assert_nearest_docs(query_props, 6, [[0,2],[2,4],[4,6],[6,8],[8,10]], {:filter => "0"})
    assert_nearest_docs(query_props, 6, [[1,3],[3,5],[5,7],[7,9],[9,11]], {:filter => "1"})
  end

  def run_common_or_query_tests(query_props)
    # Using OR query, combining nearest neighbor and text matching.
    # The expected result triples are specified as [exp_docid,exp_distance,exp_earliness].
    # When exp_distance=nil, the distance/closeness raw score is not calculated during matching.
    # This is only calculated for docid 0 in the following queries, as we ask for targetHits=1.
    query_props[:x_0] = -2
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[6,nil,0.2]], {:text => "6", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[7,nil,0.2]], {:text => "7", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[8,nil,0.2]], {:text => "8", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[9,nil,0.2]], {:text => "9", :combined => true})

    assert_nearest_docs(query_props, 1, [[0,2,1.0],[5,nil,0.8]], {:text => "0", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[1,nil,0.8],[6,nil,0.6]], {:text => "1", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0],[2,nil,0.6],[7,nil,0.4]], {:text => "2", :combined => true})

    assert_nearest_docs(query_props, 1, [[7,nil,0.2],[0,99,0.0]], {:text => "7", :combined => true, :x_0 => -99})
  end


  def run_brute_force_tests(query_props)
    query_props[:approx] = "false"
    run_common_tests(query_props)
    run_common_and_query_tests(query_props)
    run_common_or_query_tests(query_props)

    # In this case we always find a nearer document when evaluating the next,
    # so all documents go through the heap used by the backend search iterator.
    # This means all documents are returned in the result as well.
    assert_nearest_docs(query_props, 3, [[9,2],[8,3],[7,4],[6,5],[5,6],[4,7],[3,8],[2,9],[1,10],[0,11]], {:x_0 => 11})
  end

  def run_hnsw_tests(query_props)
    run_common_tests(query_props)
    query_props[:approx] = "true"
    run_common_tests(query_props)
    run_common_and_query_tests(query_props)
    run_common_or_query_tests(query_props)

    run_hnsw_and_query_tests(query_props)

    # This is different from the brute force test as we search the hnsw index and find the top k hits up front and can return only those.
    assert_nearest_docs(query_props, 3, [[9,2],[8,3],[7,4]], {:x_0 => 11})
    assert_nearest_docs(query_props, 1, [[7,0]], {:x_0 => 7})

    stats = get_nni_stats('pos')
    puts "Nearest Neighbor Index statistics: #{stats}"
    assert_equal(11, stats['nodes'])
    assert_equal(0, stats['unreachable_nodes'])
  end

  def run_hnsw_and_query_tests(query_props)
    # Using AND query filter.
    # HNSW will be used when the iterator is strict (k is less than 5
    # since filter produces 5 hits).
    query_props[:x_0] = -2
    # Bruteforce is used always when iterator is NOT strict:
    assert_nearest_docs(query_props, 6, [[0,2],[2,4],[4,6],[6,8],[8,10]], {:filter => "0"})
    assert_nearest_docs(query_props, 6, [[1,3],[3,5],[5,7],[7,9],[9,11]], {:filter => "1"})

    # This is different from the brute force test as we search the hnsw index and find the top k hits up front and can return only those.
    query_props[:x_0] = 11
    assert_nearest_docs(query_props, 1, [[8,3]], {:filter => "0"})
    assert_nearest_docs(query_props, 1, [[9,2]], {:filter => "1"})
    assert_nearest_docs(query_props, 2, [[8,3],[6,5]], {:filter => "0"})
    assert_nearest_docs(query_props, 2, [[9,2],[7,4]], {:filter => "1"})
  end

  def assert_flushing_of_hnsw_index
    vespa.search["search"].first.trigger_flush
    file_name = full_attribute_path("pos/snapshot-22/pos.nnidx")
    result = nil
    30.times do
      puts "Checking if hnsw index file '#{file_name}' exists..."
      result = vespa.adminserver.remote_eval("File.exists?(\"#{file_name}\")")
      break if result == true
      sleep 1
    end
    assert_equal(true, result, "Hnsw index file '#{file_name}' does not exists")
  end

  def full_attribute_path(attr_file)
    "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/n0/documents/test/0.ready/attribute/#{attr_file}"
  end

  def get_docid(i, dt = 'test')
    "id:test:#{dt}::#{i}";
  end

  X_1_POS = 3

  def feed_docs(populate_pos_field = true)
    # text field for 10 documents:
    txt = [ "0 x x x 0", "x 1 x x 1", "x x 2 x 2", "x x x 3 3", " 4 x x x 4",
            "x 0 x x 5", "x x 1 x 6", "x x x 2 7", "3 x x x 8", " x 4 x x 9" ]
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change "targetNumHits" and get deterministic behaviour.
    for i in 0...10 do
      doc = Document.new("test", get_docid(i)).
        add_field("text", txt[i]).
        add_field("filter", "#{i % 2}")
      if populate_pos_field
        doc.add_field("pos", { "values" => [i, X_1_POS] })
      end
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:test', 10)
  end

  def feed_assign_updates
    for i in 0...10 do
      upd = DocumentUpdate.new("test", get_docid(i))
      upd.addOperation("assign", "pos", { "values" => [i, X_1_POS] })
      vespa.document_api_v1.update(upd)
    end
  end

  def feed_campaign_docs
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change "targetNumHits" and get deterministic behaviour.
    (0...10).reverse_each do |i|
      doc = Document.new('campaign', get_docid(i, 'campaign')).
        add_field('cpos', { 'values' => [i, X_1_POS] }).
        add_field('title', "campaign #{i}")
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:campaign', 10)
  end

  def feed_ad_docs
    # text field for 10 documents:
    txt = [ '0 x x x 0', 'x 1 x x 1', 'x x 2 x 2', 'x x x 3 3', ' 4 x x x 4',
            'x 0 x x 5', 'x x 1 x 6', 'x x x 2 7', '3 x x x 8', ' x 4 x x 9' ]
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change 'targetNumHits' and get deterministic behaviour.
    (0...10).each do |i|
      doc = Document.new('ad', get_docid(i, 'ad')).
        add_field('campaign_ref', get_docid(i, 'campaign')).
        add_field('text', txt[i]).
        add_field('filter', "#{i % 2}")
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:ad', 10)
  end

  def assert_nearest_docs(setup, target_num_hits, exp_results, overrides = {})
    query_props = setup.merge(overrides)
    query_props[:target_num_hits] = target_num_hits
    query_props[:query_tensor] ||= 'qpos_double'
    query_props[:doc_tensor] ||= 'pos'
    query = get_query(query_props)
    puts "assert_nearest_docs(): query='#{query}'"
    result = search(query)
    puts "result:"
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
      exp_distance = exp_result[1]
      exp_closeness = (exp_distance != nil) ? 1.0 / (1.0 + exp_distance) : 0
      exp_distance = (exp_distance != nil) ? exp_distance : Float::MAX
      exp_earliness = exp_result[2]
      # This matches the expression used i rank-profile 'combined'
      exp_score = 10 * exp_closeness + exp_earliness
      exp_features = { "distance(#{doc_tensor})" => exp_distance,
                       "distance(label,nns)" => exp_distance,
                       "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_closeness,
                       "itemRawScore(nns)" => exp_closeness }
    else
      exp_distance = exp_result[1]
      exp_score = 15 - exp_distance
      exp_closeness = 1.0 / (1.0 + exp_distance)
      exp_features = { "euclidean_distance_#{query_tensor}" => exp_distance,
                       "distance(#{doc_tensor})" => exp_distance,
                       "distance(label,nns)" => exp_distance,
                       "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_closeness,
                       "itemRawScore(nns)" => exp_closeness }
    end
    doc_type = qp[:doc_type] || 'test'
    act_docid = result.hit[i].field['documentid']
    puts "assert_single_doc(): #{act_docid}"
    assert_equal(get_docid(exp_docid, doc_type), act_docid)
    assert_relevancy(result, exp_score, i)
    assert_features(exp_features, result.hit[i].field['summaryfeatures'])
  end

  def get_query(qprops)
    x_0 = qprops[:x_0] || 0
    x_1 = qprops[:x_1] || X_1_POS
    target_num_hits = qprops[:target_num_hits] || 10
    query_tensor = qprops[:query_tensor]
    doc_tensor = qprops[:doc_tensor]
    doc_type = qprops[:doc_type]
    approx = qprops[:approx]
    filter = qprops[:filter]
    text = qprops[:text]

    result = "yql=select * from sources * where {targetNumHits: #{target_num_hits},"
    result += "approximate: #{approx}," if approx
    result += "label: \"nns\"} nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += " and filter contains \"#{filter}\"" if filter
    result += " or text contains \"#{text}\"" if text
    result += "&ranking.features.query(#{query_tensor})={{x:0}:#{x_0},{x:1}:#{x_1}}"
    result += "&ranking.profile=combined" if qprops[:combined]
    return result
  end

  def get_nni_stats(attribute)
    uri = "/documentdb/test/subdb/ready/attribute/#{attribute}"
    stats = vespa.search["search"].first.get_state_v1_custom_component(uri)
    assert(stats['tensor'])
    assert(stats['tensor']['nearest_neighbor_index'])
    stats['tensor']['nearest_neighbor_index']
  end

  def teardown
    stop
  end
end
