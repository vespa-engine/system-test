# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DistanceMetricsTest < IndexedStreamingSearchTest

  def setup
    set_owner('toregge')
    set_description("Test the distance metrics used by nearest neighbor search")
    @namespace = 'test'
    @doc_type = 'distances'
  end

  def test_distance_metrics
    deploy_app(SearchApp.new.sd(selfdir+'distances.sd').threads_per_search(1).enable_document_api)
    start
    feed_doc
    check_euclidean_distance_metrics
    check_angular_distance_metrics
    check_prenormalized_angular_distance_metrics
    check_geodegrees_distance_metrics
    check_hamming_distance_metrics
    check_dotproduct_distance_metrics
  end

  def check_euclidean_distance_metrics
    check_distance_metrics('euclidean', 'euclidean', [10, 2], 0.1, 9.0, 0.1, 0.1)
  end

  def check_angular_distance_metrics
    # 45 degrees
    ang_dist = Math::PI / 4
    ang_closeness = 1.0 / (1.0 + ang_dist)
    check_distance_metrics('angular', 'angular', [2, 2], ang_closeness, ang_dist, ang_closeness, ang_closeness)
  end

  def check_prenormalized_angular_distance_metrics
    # 45 degrees
    sqrt_half = Math.sqrt(0.5)
    prenorm_dist = 1.0 - sqrt_half
    prenorm_closeness = 1.0 / (1.0 + prenorm_dist)
    check_distance_metrics('prenorm','prenormalized-angular', [sqrt_half, sqrt_half], prenorm_closeness, prenorm_dist, prenorm_closeness, prenorm_closeness)
  end

  def check_geodegrees_distance_metrics
    # 90 degrees, doc at equator, query at north pole
    earth_mean_radius = 6371.0088
    geo_dist = earth_mean_radius * Math::PI / 2
    geo_closeness = 1.0 / (1.0 + geo_dist)
    check_distance_metrics('geodegrees', 'geodegrees', [90, 0], geo_closeness, geo_dist, geo_closeness, geo_closeness)
  end

  def check_hamming_distance_metrics
    hamming_dist = 6.0
    hamming_closeness = 1.0 / (1.0 + hamming_dist)
    check_distance_metrics('hamming', 'hamming', [0, 8], hamming_closeness, hamming_dist, hamming_closeness, hamming_closeness)
  end

  def check_dotproduct_distance_metrics
    # Positive correlation
    dotproduct_dist = -14.0
    dotproduct_closeness = -dotproduct_dist
    check_distance_metrics('dotproduct', 'dotproduct', [3, 4], dotproduct_closeness, dotproduct_dist, dotproduct_closeness, dotproduct_closeness)
    # Negative correlation
    dotproduct_dist = 14.0
    dotproduct_closeness = -dotproduct_dist
    check_distance_metrics('dotproduct', 'dotproduct', [-3, -4], dotproduct_closeness, dotproduct_dist, dotproduct_closeness, dotproduct_closeness)
  end

  def make_pos(dpos)
    { "values" => dpos }
  end

  def search_pos(qpos, doc_tensor: nil, distance_threshold: nil, or_true: false, verbose: false)
    qpos_name = (doc_tensor == 'hamming') ? 'qpos_int8' : 'qpos'
    yql = "select #{doc_tensor},summaryfeatures from sources * where {targetHits: 1,"
    yql += "distanceThreshold: #{distance_threshold}," if distance_threshold
    yql += "label: \"nns\"} nearestNeighbor(#{doc_tensor},#{qpos_name})"
    yql += " or true" if or_true
    form = [['yql', yql],
            ["ranking.features.query(#{qpos_name})", qpos.to_s],
            ['hits', '1'],
            ['presentation.format', 'json']]
    encoded_form = URI.encode_www_form(form)
    puts "encoded_form='#{encoded_form}'"
    result = search("#{encoded_form}")
    if result.hitcount > 0 && verbose
      fields = result.json["root"]["children"][0]["fields"]
      puts JSON.pretty_generate(fields)
      puts "----"
    end
    result
  end

  def assert_distance_metrics(result, eps, exp_relevancy, exp_distance, exp_closeness, exp_rawscore)
    assert_hitcount(result, 1)
    hit = result.hit[0]
    act_relevancy = hit.field['relevancy']
    assert_approx(exp_relevancy, act_relevancy, eps, "Expected relevancy #{exp_relevancy} but was #{act_relevancy}")
    sf = hit.field['summaryfeatures']
    act_distance = sf['distance(label,nns)']
    assert_approx(exp_distance, act_distance, eps, "Expected distance #{exp_distance} but was #{act_distance}")
    act_closeness = sf['closeness(label,nns)']
    assert_approx(exp_closeness, act_closeness, eps, "Expected closeness #{exp_closeness} but was #{act_closeness}")
    act_rawscore = sf['itemRawScore(nns)']
    assert_approx(exp_rawscore, act_rawscore, eps, "Expected rawscore #{exp_rawscore} but was #{act_rawscore}")
  end

  def check_distance_metrics(field, metric, qpos, exp_relevancy, exp_distance, exp_closeness, exp_rawscore)
    puts "Checking metric #{metric} using field #{field}"
    eps = 1e-6
    result = search_pos(qpos, doc_tensor: field, verbose: true)
    assert_distance_metrics(result, eps, exp_relevancy, exp_distance, exp_closeness, exp_rawscore)
    result0 = search_pos(qpos, doc_tensor: field, distance_threshold: exp_distance - eps)
    assert_hitcount(result0, 0)
    result1 = search_pos(qpos, doc_tensor: field, distance_threshold: exp_distance + eps)
    assert_hitcount(result1, 1)
    result2 = search_pos(qpos, doc_tensor: field, distance_threshold: exp_distance - eps, or_true: true, verbose: true)
    assert_hitcount(result2, 1)
    assert_distance_metrics(result2, eps, exp_relevancy, exp_distance, exp_closeness, 0.0)
  end

  def feed_doc
    doc = Document.new("distances", "id:#{@namespace}:#{@doc_type}::0").
            add_field('euclidean', make_pos([1, 2])).
            add_field('angular', make_pos([0, 2])).
            add_field('prenorm', make_pos([0, 1])).
            add_field('geodegrees', make_pos([0, 0])).
            add_field('hamming', make_pos([3, 7])).
            add_field('dotproduct', make_pos([2, 2]))
    vespa.document_api_v1.put(doc)
  end

  def teardown
    stop
  end
end
