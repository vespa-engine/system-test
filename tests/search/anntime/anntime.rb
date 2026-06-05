# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'json'

class AnnTimeout < IndexedOnlySearchTest

  NUM_DOCUMENTS = 100_000
  NUM_DIMENSIONS = 2048

  # Epsilon for timebudget/timeout comparisons in ms
  # Quite relaxed for now
  TIMEBUDGET_EPSILON = 10
  TIMEOUT_EPSILON = 10

  # For debugging purposes
  # Whether to print the whole nearestNeighbor block from the trace
  PRINT_NN_INFO = false

  def setup
    set_owner("boeker")
    @valgrind = false
    @valgrind_opt = nil
  end

  ################################################################################
  # Helper functions for feeding
  ################################################################################

  def get_container
    vespa.qrserver["0"] or vespa.container.values.first
  end

  def compile_document_generator
    @tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -std=c++20 -O3 -o #{@tmp_bin_dir}/docs #{selfdir}data/docs.cpp")
  end

  def feed_and_wait(name, num_documents, num_dimensions)
    puts "Feeding documents"
    @container.execute("#{@tmp_bin_dir}/docs #{name} #{num_documents} #{num_dimensions} | vespa-feed-perf")
    wait_for_atleast_hitcount("query=sddocname:#{name}", num_documents)
  end

  ################################################################################
  # The actual test case and test-case logic
  ################################################################################

  def test_anntime
    set_description("Verify that anntimebudget and anntimeout are respected")
    deploy_app(SearchApp.new.sd(selfdir + "anntime/test.sd").search_dir(selfdir + "anntime/search"))
    @container = get_container
    compile_document_generator
    start

    puts "Feeding #{NUM_DOCUMENTS} documents"
    feed_and_wait("test", NUM_DOCUMENTS, NUM_DIMENSIONS)

    query_one = {
      'yql' => 'select * from sources * where ({targetHits:100}nearestNeighbor(tensor_field, q_v1))',
      'input.query(q_v1)' => "#{[0.0] * NUM_DIMENSIONS}"
    }

    query_two = {
      'yql' => 'select * from sources * where ({targetHits:100}nearestNeighbor(tensor_field, q_v1)) '\
                                              'OR ({targetHits:500}nearestNeighbor(tensor_field, q_v2))',
      'input.query(q_v1)' => "#{[0.0] * NUM_DIMENSIONS}",
      'input.query(q_v2)' => "#{[50.0] * NUM_DIMENSIONS}"
    }

    query_three = {
      'yql' => 'select * from sources * where ({targetHits:100}nearestNeighbor(tensor_field, q_v1)) '\
                                              'OR ({targetHits:500}nearestNeighbor(tensor_field, q_v2)) '\
                                              'OR ({targetHits:1000}nearestNeighbor(tensor_field, q_v3))',
      'input.query(q_v1)' => "#{[0.0] * NUM_DIMENSIONS}",
      'input.query(q_v2)' => "#{[50.0] * NUM_DIMENSIONS}",
      'input.query(q_v3)' => "#{[100.0] * NUM_DIMENSIONS}"
    }

    timeout = 10.0
    budgets = [5.0, 10.0, 20.0, 30.0, 50.0]
    factors = [0.001, 0.002, 0.004, 0.006, 0.01]

    puts "\ntimeout = #{timeout * 1000.0} ms"
    puts "epsilon for time budget = #{TIMEBUDGET_EPSILON} ms"
    puts "epsilon for timeout = #{TIMEOUT_EPSILON} ms"

    puts "\nSending some warmup queries first"

    # Warmup queries with anntimebudget
    budgets.each do |budget|
      search_with_trace(timeout, make_anntimebudget_query(query_one, budget))
      search_with_trace(timeout, make_anntimebudget_query(query_two, budget))
      search_with_trace(timeout, make_anntimebudget_query(query_three, budget))
    end

    # Warmup queries with anntimeout
    factors.each do |factor|
      search_with_trace(timeout, make_anntimeout_query(query_one, factor))
      search_with_trace(timeout, make_anntimeout_query(query_two, factor * 2))
      search_with_trace(timeout, make_anntimeout_query(query_three, factor * 3))
    end

    # Actual tests for anntimebudget
    verify_anntimebudget(timeout, budgets, query_one)
    verify_anntimebudget(timeout, budgets, query_two)
    verify_anntimebudget(timeout, budgets, query_three)

    # Actual tests for anntimeout
    verify_anntimeout(timeout, factors, query_one)
    verify_anntimeout(timeout, factors.map{ |n| n * 2 }, query_two)
    verify_anntimeout(timeout, factors.map{ |n| n * 3 }, query_three)
  end

  def verify_anntimebudget(timeout, budgets, query)
    puts "\nTesting anntimebudget"

    nn_operators = get_num_nn_operators(query)
    assert(nn_operators > 0)

    budgets.each do |budget|
      puts "anntimebudget = #{'%.3f' % budget} ms"
      query_with_params = make_anntimebudget_query(query, budget)
      result, nn_info, metrics = search_and_get_nn_info_and_metrics(timeout, query_with_params)
      assert_equal(nn_operators, nn_info.length)

      # Check that we got hits
      assert(result.hitcount > 0)

      # Check that time used on NNS from trace matches the specified anntimebudget
      nn_info.each do |nn_search|
        time_info = extract_ann_time_info(nn_search, budget)
        assert_approx(budget, time_info[:time_used], TIMEBUDGET_EPSILON)
        assert_approx(budget, time_info[:time_allocated], TIMEBUDGET_EPSILON)
        assert_equal("true", time_info[:terminated_early])
        assert_equal("false", time_info[:timeout_hit])
      end

      # Check that the metrics match what we expect
      assert_equal(0, metrics[:timeouts])
      assert_equal(1, metrics[:time_count])
      assert_approx(nn_operators * budget, metrics[:time_total], nn_operators * TIMEBUDGET_EPSILON)

      # Check that query is NOT reported as degraded
      coverage = result.json['root']['coverage']
      assert(!coverage.key?('degraded'))
    end
  end

  def make_anntimebudget_query(query, budget)
    query.merge({ 'hits' => 10,
                  'summary' => 'minimal',
                  'ranking.matching.explorationSlack' => 1.0,
                  'ranking.matching.anntimebudget' => "#{budget}ms",
                })
  end

  def verify_anntimeout(timeout, factors, query)
    puts "\nTesting anntimeout"

    nn_operators = get_num_nn_operators(query)
    assert(nn_operators > 0)

    factors.each do |factor|
      estimated_time_until_anntimeout = (factor * 0.5 * timeout * 1000.0) / nn_operators
      puts "anntimeout.factor = #{'%.3f' % factor} => #{'%.3f' % estimated_time_until_anntimeout} ms"
      query_with_params = make_anntimeout_query(query, factor)
      result, nn_info, metrics = search_and_get_nn_info_and_metrics(timeout, query_with_params)
      assert_equal(nn_operators, nn_info.length)

      # Check that we got hits despite the timeout
      assert(result.hitcount > 0)

      # Check that the timeout was respected
      nn_info.each do |nn_search|
        time_info = extract_ann_time_info(nn_search, estimated_time_until_anntimeout)
        assert_approx(estimated_time_until_anntimeout, time_info[:time_used], TIMEOUT_EPSILON)
        assert_approx(estimated_time_until_anntimeout, time_info[:time_allocated], TIMEOUT_EPSILON)
        assert_equal("true", time_info[:terminated_early])
        assert_equal("true", time_info[:timeout_hit])
      end

      # Check that the metrics match what we expect
      assert_equal(1, metrics[:timeouts])
      assert_equal(1, metrics[:time_count])
      assert_approx(nn_operators * estimated_time_until_anntimeout, metrics[:time_total], nn_operators * TIMEOUT_EPSILON)

      # Check that query is reported as degraded
      # These values are bools and not strings
      degraded = result.json['root']['coverage']['degraded']
      assert_equal(true, degraded['anntimeout'])
      assert_equal(false, degraded['timeout'])
    end
  end

  def make_anntimeout_query(query, factor)
    query.merge({ 'hits' => 1,
                  'summary' => 'minimal',
                  'ranking.matching.explorationSlack' => 1.0,
                  'ranking.matching.anntimeout.enable' => "true", # Not necessary, should be true by default
                  'ranking.matching.anntimeout.factor' => "#{factor}",
                  })
  end

  ################################################################################
  # Helper function to get nearest-neighbor-related info from query
  ################################################################################

  def get_num_nn_operators(query)
    puts "yql = #{query['yql']}"
    # Get number of nearestNeighbor operators in query
    nn_operators = query['yql'].scan('nearestNeighbor').length
    puts "#{nn_operators} nearestNeighbor operators"

    nn_operators
  end

  ################################################################################
  # Helper functions to get timing-related info from trace
  ################################################################################

  def search_with_trace(timeout, query)
    trace = {
      'trace.explainLevel' => 1,
      'trace.level' => 1,
      'trace.profileDepth' => 100,
      'trace.timestamps' => true
    }
    search_with_timeout(timeout, query.merge(trace))
  end

  def find_in_json(obj, type)
    list = []
    if obj.is_a?(Hash)
      if obj.has_key?('[type]') && obj['[type]'] == type
        list.append(obj)
      end
      list.concat(obj.map { |k, v| find_in_json(v, type) }.flatten)
    end
    if obj.is_a?(Array)
      list.concat(obj.map { |v| find_in_json(v, type) }.flatten)
    end
    list
  end

  def search_and_get_nn_info_and_metrics(timeout, query)
    ann_timeouts_before, ann_time_count_before, ann_time_total_before = get_metrics "test"
    result = search_with_trace(timeout, query)
    ann_timeouts_after, ann_time_count_after, ann_time_total_after = get_metrics "test"

    metrics = {}
    metrics[:timeouts] = ann_timeouts_after - ann_timeouts_before
    metrics[:time_count] = ann_time_count_after - ann_time_count_before
    metrics[:time_total] = (ann_time_total_after - ann_time_total_before) * 1000.0 # Convert to ms

    puts "increases in metrics: timeouts = #{metrics[:timeouts]}, time_count = #{metrics[:time_count]}, time_total = #{'%6.3f' %  metrics[:time_total]}"

    nn_info = find_in_json(result.json, 'search::queryeval::NearestNeighborBlueprint')

    if PRINT_NN_INFO
      puts "NN info:"
      puts JSON.pretty_generate(nn_info)
    end

    return result, nn_info, metrics
  end

  def extract_ann_time_info(nn_search, expected_time)
    ann_time_info = {}
    ann_time_info[:time_allocated] = nn_search['time_allocated'].to_f
    ann_time_info[:time_used] = nn_search['time_used'].to_f
    ann_time_info[:terminated_early] = nn_search['terminated_early'].to_s
    ann_time_info[:timeout_hit] = nn_search['timeout_hit'].to_s

    puts "  time_used / time_allocated:  #{'%6.3f' % ann_time_info[:time_used]} ms / #{'%6.3f' % ann_time_info[:time_allocated]} ms" \
         ", early: #{ann_time_info[:terminated_early]}, timeout: #{ann_time_info[:timeout_hit]}"
    puts "      delta / delta:           #{'%6.3f' % (ann_time_info[:time_used] - expected_time).abs} ms " \
           "/ #{'%6.3f' % (ann_time_info[:time_allocated] - expected_time).abs} ms"
    ann_time_info
  end

  ################################################################################
  # Helper functions to get timing-related metrics
  ################################################################################

  def get_metrics(doc_name)
    metrics = vespa.search["search"].first.get_total_metrics
    extract_metrics(metrics, doc_name)
  end

  def extract_metrics(metrics, doc_name)
    ann_timeouts = extract_metric(metrics, doc_name, "approximate_nns_timed_out_queries")
    ann_time = extract_metric(metrics, doc_name, "query_approximate_nns_time")
    return ann_timeouts["count"], ann_time["count"], ann_time["sum"]
  end

  def extract_metric(metrics, doc_name, name)
    metrics.get("content.proton.documentdb.matching.#{name}", {"documenttype" => doc_name})
  end

end
