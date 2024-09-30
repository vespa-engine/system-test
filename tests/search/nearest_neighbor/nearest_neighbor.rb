# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class NearestNeighborTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_nearest_neighbor_operator
    set_description("Test the nearest neighbor search operator (brute force and over hnsw index) with dense tensors")
    run_test_nearest_neighbor_operator(false)
  end

  def test_nearest_neighbor_operator_mixed
    set_description("Test the nearest neighbor search operator (brute force and over hnsw index) with mixed tensors")
    run_test_nearest_neighbor_operator(true)
  end

  def run_test_nearest_neighbor_operator(mixed)
    @mixed = mixed
    @multipoint_mapping = nil
    sd_file = mixed ? selfdir + "mixed/test.sd" : selfdir + "test.sd"
    deploy_app(SearchApp.new.sd(sd_file).threads_per_search(1))
    start
    feed_docs

    run_all_tests
    assert_flushing_of_hnsw_index unless is_streaming
    restart_proton("test", 10)
    run_all_tests

    feed_docs
    run_all_tests

    feed_docs(false)
    feed_assign_updates
    run_all_tests
  end

  def test_nearest_neighbor_operator_mixed_multipoint
    sd_file = selfdir + "mixed/test.sd"
    run_test_nearest_neighbor_operator_mixed_multipoint(sd_file)
  end

  def modify_mixed_sd_file_for_fast_rank
    lines = File.readlines(selfdir + "mixed/test.sd")
    lines.each do |line|
      line.sub!("# attribute:", "attribute:")
    end
    sd_dir = selfdir + "mixed_fast_rank"
    sd_file = sd_dir + "/test.sd"
    FileUtils.rm_rf(sd_dir)
    FileUtils.mkdir_p(sd_dir)
    File.write(sd_file, lines.join)
    return sd_file
  end

  def test_nearest_neighbor_operator_mixed_fast_rank_multipoint
    sd_file = modify_mixed_sd_file_for_fast_rank
    run_test_nearest_neighbor_operator_mixed_multipoint(sd_file)
  end

  def run_test_nearest_neighbor_operator_mixed_multipoint(sd_file)
    @mixed = true
    @multipoint_mapping = [[0],[1],[2],[3],[4,6],[5],[7],[8],[9],[10]]
    deploy_app(SearchApp.new.sd(sd_file).threads_per_search(1))
    start
    feed_docs
    run_multipoint_tests(true)
    assert_flushing_of_hnsw_index unless is_streaming
    restart_proton("test", 10)
    run_multipoint_tests(true)
    feed_docs
    run_multipoint_tests(true)
    @multipoint_mapping = [[0],[1],[2,4,7],[3],[5],[6],[8],[9,11],[10],[12]]
    feed_docs(false)
    feed_assign_updates
    run_multipoint_tests(false)
  end

  def run_multipoint_tests(first_pass)
    assert_multipoint_docs(first_pass, true)
    assert_multipoint_docs(first_pass, false)
  end

  def only_verify_atleast_hitcount(query_props)
    # In streaming search we don't control the order in which documents are evaluated,
    # and more than targetHits are typically returned from the nearestNeighbor operator.
    # This ensures that we only check the targetHits first documents.
    query_props[:atleast_hitcount] = true if is_streaming
  end

  def assert_multipoint_docs(first_pass, approx)
    query_props = {:approx => approx.to_s}
    only_verify_atleast_hitcount(query_props)
    if first_pass
      assert_nearest_docs(query_props, 7, [[0,2,0],[1,3,0],[2,4,0],[3,5,0],[4,6,0],[5,7,0],[6,9,0]], {:x_0 => -2})
      if approx
        assert_nearest_docs(query_props, 7, [[9,1,0],[8,2,0],[7,3,0],[6,4,0],[4,5,1],[5,6,0],[3,8,0]], {:x_0 => 11})
      else
        assert_nearest_docs(query_props, 7, [[9,1,0],[8,2,0],[7,3,0],[6,4,0],[4,5,1],[5,6,0],[3,8,0],[2,9,0],[1,10,0],[0,11,0]], {:x_0 => 11})
      end
    else
      assert_nearest_docs(query_props, 10, [[0,2,0],[1,3,0],[2,4,0],[3,5,0],[4,7,0],[5,8,0],[6,10,0],[7,11,0],[8,12,0],[9,14,0]], {:x_0 => -2})
      assert_nearest_docs(query_props, 10, [[9,1,0],[7,2,1],[8,3,0],[6,5,0],[2,6,2],[5,7,0],[4,8,0],[3,10,0],[1,12,0],[0,13,0]], {:x_0 => 13})
    end
  end

  def self.final_test_methods
    [ "test_nns_via_parent" ]
  end

  def test_nns_via_parent
    set_description('Test the nearest neighbor search operator with imported attribute')
    # Parent-child is NOT supported in streaming search
    @params = { :search_type => "INDEXED" }
    @mixed = false
    @multipoint_mapping = nil
    deploy_app(SearchApp.new
                 .sd(selfdir + 'campaign.sd', { :global => true })
                 .sd(selfdir + 'ad.sd')
                 .threads_per_search(1))
    start
    feed_campaign_docs
    feed_ad_docs
    run_brute_force_tests({:query_tensor => 'qpos_double', :doc_type => 'ad'})
  end

  def run_all_tests
    run_brute_force_tests({:query_tensor => "qpos_double"})
    run_brute_force_tests({:query_tensor => "qpos_float"})
    run_hnsw_tests({:query_tensor => "qpos_double"}) unless is_streaming
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
    # The expected result tuples are specified as [exp_docid,exp_distance,exp_earliness,has_raw_score].
    # Raw score is only calculated for docid 0 (the closest doc) as we ask for targetHits=1 (and distanceThreshold=2 in the streaming search case).
    # With distanceThreshold set we ensure that only docid 0 is returned by the nearestNeighbor operator,
    # and this is needed when using streaming search as we cannot control the order in which documents are evaluated.
    # For all other documents the distance / closeness is calculated on the fly by the rank features.
    query_props[:x_0] = -2
    query_props[:distance_threshold] = 2.0
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[6,8,0.2,false]], {:text => "6", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[7,9,0.2,false]], {:text => "7", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[8,10,0.2,false]], {:text => "8", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[9,11,0.2,false]], {:text => "9", :combined => true})

    assert_nearest_docs(query_props, 1, [[0,2,1.0,true],[5,7,0.8,false]], {:text => "0", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[1,3,0.8,false],[6,8,0.6,false]], {:text => "1", :combined => true})
    assert_nearest_docs(query_props, 1, [[0,2,0.0,true],[2,4,0.6,false],[7,9,0.4,false]], {:text => "2", :combined => true})

    query_props[:distance_threshold] = 99.0
    assert_nearest_docs(query_props, 1, [[7,106,0.2,false],[0,99,0.0,true]], {:text => "7", :combined => true, :x_0 => -99})
  end


  def run_brute_force_tests(query_props)
    query_props[:approx] = "false"
    only_verify_atleast_hitcount(query_props)
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
    if @mixed
      assert(stats['nodes'] >= 10)
    else
      assert_equal(10, stats['nodes'])
    end
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
      result = vespa.adminserver.remote_eval("File.exist?(\"#{file_name}\")")
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

  def make_pos(i)
    if @mixed
      if @multipoint_mapping
        positions = @multipoint_mapping[i]
      else
        positions = [ i ]
      end
      blocks = [ ]
      for j in 0...positions.size
        blocks.push({ "address" => { "a" => j.to_s, "b" => (j + 10).to_s}, "values" => [ positions[j], X_1_POS] })
      end
      { "blocks" => blocks }
    else
      { "values" => [ i, X_1_POS] }
    end
  end

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
        doc.add_field("pos", make_pos(i))
      end
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:test', 10)
  end

  def feed_assign_updates
    for i in 0...10 do
      upd = DocumentUpdate.new("test", get_docid(i))
      upd.addOperation("assign", "pos", make_pos(i))
      vespa.document_api_v1.update(upd)
    end
  end

  def feed_campaign_docs
    # Inserting one and one document ensures the same (and deterministic) order of the documents on the content node.
    # This means we can change "targetNumHits" and get deterministic behaviour.
    (0...10).reverse_each do |i|
      doc = Document.new('campaign', get_docid(i, 'campaign')).
        add_field('cpos', make_pos(i)).
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

  def assert_nearest_docs(setup, target_hits, exp_results, overrides = {})
    query_props = setup.merge(overrides)
    query_props[:target_hits] = target_hits
    query_props[:query_tensor] ||= 'qpos_double'
    query_props[:doc_tensor] ||= 'pos'
    query = get_query(query_props)
    puts "assert_nearest_docs(): query='#{query}'"
    result = search(query)
    puts "result:"
    if query_props[:atleast_hitcount]
      assert(result.hitcount >= exp_results.length)
    else
      assert_hitcount(result, exp_results.length)
    end
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
      exp_closeness = 1.0 / (1.0 + exp_distance)
      exp_earliness = exp_result[2]
      has_raw_score = exp_result[3]
      exp_raw_score = has_raw_score ? exp_closeness : 0
      # This matches the expression used in rank-profile 'combined'
      exp_score = 10 * exp_closeness + exp_earliness
      exp_features = { "distance(#{doc_tensor})" => exp_distance,
                       "distance(label,nns)" => exp_distance,
                       "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_raw_score,
                       "itemRawScore(nns)" => exp_raw_score }
    else
      exp_distance = exp_result[1]
      exp_score = 15 - exp_distance
      exp_closeness = 1.0 / (1.0 + exp_distance)
      exp_features = { "distance(#{doc_tensor})" => exp_distance,
                       "distance(label,nns)" => exp_distance,
                       "closeness(#{doc_tensor})" => exp_closeness,
                       "closeness(label,nns)" => exp_closeness,
                       "rawScore(#{doc_tensor})" => exp_closeness,
                       "itemRawScore(nns)" => exp_closeness }
      unless @multipoint_mapping
        exp_features["euclidean_distance_#{query_tensor}"] = exp_distance
      else
        closest_feature_label = exp_result[2]
        closest_feature = {"type"=>"tensor(a{},b{})",
                           "cells"=>[{"address"=>{"a"=>closest_feature_label.to_s,
                                                  "b"=>(closest_feature_label +  10).to_s},
                                      "value"=>1.0}]}
        exp_features["closest(pos)"] = closest_feature
        exp_features["closest(pos,nns)"] = closest_feature
        exp_features["label_value"] = closest_feature_label.to_f + 100
      end
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
    target_hits = qprops[:target_hits] || 10
    query_tensor = qprops[:query_tensor]
    doc_tensor = qprops[:doc_tensor]
    doc_type = qprops[:doc_type]
    approx = qprops[:approx]
    distance_threshold = qprops[:distance_threshold]
    filter = qprops[:filter]
    text = qprops[:text]

    result = "yql=select * from sources * where {targetHits: #{target_hits},"
    result += "approximate: #{approx}," if approx
    result += "distanceThreshold: #{distance_threshold}," if distance_threshold
    result += "label: \"nns\"} nearestNeighbor(#{doc_tensor},#{query_tensor})"
    result += " and filter contains \"#{filter}\"" if filter
    result += " or text contains \"#{text}\"" if text
    result += "&ranking.features.query(#{query_tensor})=[#{x_0},#{x_1}]"
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
