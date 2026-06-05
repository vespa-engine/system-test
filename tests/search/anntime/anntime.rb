# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'json'

class AnnTimeout < IndexedOnlySearchTest

  NUM_DOCUMENTS = 100_000
  NUM_DIMENSIONS = 2048

  # Epsilon for timebudget/timeout comparisons in ms
  TIMEBUDGET_EPSILON = 5
  TIMEOUT_EPSILON = 5

  # How often to send each query
  REPETITIONS = 20

  # For debugging purposes
  # Whether to print the whole nearestNeighbor block from the trace
  PRINT_NN_INFO = false
  # Whether to print the timing results and metric increases of each individual query
  PRINT_INDIVIDUAL_QUERIES = false

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
    puts "repetitions = #{REPETITIONS}"
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
      results, time_info, metrics = search_and_get_nn_info_and_metrics(timeout, query_with_params, nn_operators, budget, REPETITIONS)

      # Check that we got hits
      results.each do |result|
        assert(result.hitcount > 0)
      end

      # Check that time used on NNS from trace matches the specified anntimebudget
      time_info.each do |time_info_search|
        assert_approx(budget, time_info_search[:time_used], TIMEBUDGET_EPSILON)
        assert_approx(budget, time_info_search[:time_allocated], TIMEBUDGET_EPSILON)
        assert_approx(1.0, time_info_search[:terminated_early])
        assert_approx(0.0, time_info_search[:timeout_hit])
      end

      # Check that the metrics match what we expect
      assert_approx(0.0, metrics[:timeouts])
      assert_approx(1.0, metrics[:time_count])
      assert_approx(nn_operators * budget, metrics[:time_total], nn_operators * TIMEBUDGET_EPSILON)

      # Check that query is NOT reported as degraded
      results.each do |result|
        coverage = result.json['root']['coverage']
        assert(!coverage.key?('degraded'))
      end
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
      results, nn_info, metrics = search_and_get_nn_info_and_metrics(timeout, query_with_params, nn_operators, estimated_time_until_anntimeout, REPETITIONS)

      # Check that we got hits despite the timeout
      results.each do |result|
        assert(result.hitcount > 0)
      end

      # Check that the timeout was respected
      nn_info.each do |time_info_search|
        assert_approx(estimated_time_until_anntimeout, time_info_search[:time_used], TIMEOUT_EPSILON)
        assert_approx(estimated_time_until_anntimeout, time_info_search[:time_allocated], TIMEOUT_EPSILON)
        assert_approx(1.0, time_info_search[:terminated_early])
        assert_approx(1.0, time_info_search[:timeout_hit])
      end

      # Check that the metrics match what we expect
      assert_approx(1.0, metrics[:timeouts])
      assert_approx(1.0, metrics[:time_count])
      assert_approx(nn_operators * estimated_time_until_anntimeout, metrics[:time_total], nn_operators * TIMEOUT_EPSILON)

      # Check that query is reported as degraded
      results.each do |result|
        # These values are bools and not strings
        degraded = result.json['root']['coverage']['degraded']
        assert_equal(true, degraded['anntimeout'])
        assert_equal(false, degraded['timeout'])
      end
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

  def search_and_get_nn_info_and_metrics(timeout, query, expected_operator_number, expected_time, repetitions)
    # Collect the timing info as a hash from the handle of the NN operator to a list of time measurements
    collected_time_info = {}
    # Collect the timing info as an array of metric measurements
    collected_metrics = []
    # Collect all results
    collected_results = []

    repetitions.times do
      ann_timeouts_before, ann_time_count_before, ann_time_total_before = get_metrics "test"
      result = search_with_trace(timeout, query)
      collected_results << result
      ann_timeouts_after, ann_time_count_after, ann_time_total_after = get_metrics "test"

      metrics = {}
      metrics[:timeouts] = ann_timeouts_after - ann_timeouts_before
      metrics[:time_count] = ann_time_count_after - ann_time_count_before
      metrics[:time_total] = (ann_time_total_after - ann_time_total_before) * 1000.0 # Convert to ms
      if PRINT_INDIVIDUAL_QUERIES
        print_metrics metrics
      end

      collected_metrics << metrics

      nn_info = find_in_json(result.json, 'search::queryeval::NearestNeighborBlueprint')
      assert_equal(expected_operator_number, nn_info.length)

      if PRINT_NN_INFO
        puts "NN info:"
        puts JSON.pretty_generate(nn_info)
      end

      nn_info.each do |nn_search|
        handle, time_info = extract_ann_time_info(nn_search)
        if PRINT_INDIVIDUAL_QUERIES
          print_ann_time_info(time_info, expected_time)
        end
        if collected_time_info.key?(handle)
          collected_time_info[handle] << time_info
        else
          collected_time_info[handle] = [time_info]
        end
      end
    end

    # Average the collected timing info
    averaged_time_info = []
    assert_equal(expected_operator_number, collected_time_info.keys.length)
    collected_time_info.each do |handle, time_info|
      # time_info is an array of maps
      assert_equal(repetitions, time_info.length)
      averaged_time_info_for_handle = {}
      time_info[0].keys.each do |k|
        averaged_time_info_for_handle[k] = time_info.map {|x| x[k]}.inject(:+) / time_info.length
      end
      averaged_time_info << averaged_time_info_for_handle
    end

    # Average the collected metrics
    averaged_metrics = {}
    assert_equal(repetitions, collected_metrics.length)
    collected_metrics[0].keys.each do |k|
      averaged_metrics[k] = collected_metrics.map {|x| x[k]}.inject(:+) / collected_metrics.length
    end

    # Print averaged values
    puts "Averaged:"
    averaged_time_info.each do |time_info|
      print_ann_time_info(time_info, expected_time)
    end
    print_metrics averaged_metrics

    return collected_results, averaged_time_info, averaged_metrics
  end

  def extract_ann_time_info(nn_search)
    ann_time_info = {}
    ann_time_info[:time_allocated] = nn_search['time_allocated'].to_f
    ann_time_info[:time_used] = nn_search['time_used'].to_f
    ann_time_info[:terminated_early] = nn_search['terminated_early'] == true ? 1.0 : 0.0
    ann_time_info[:timeout_hit] = nn_search['timeout_hit'] == true ? 1.0 : 0.0
    handle = nn_search['fields']['[0]']['handle']

    return handle, ann_time_info
  end

  def print_ann_time_info(ann_time_info, expected_time)
    puts "  time_used / time_allocated:  #{'%6.3f' % ann_time_info[:time_used]} ms / #{'%6.3f' % ann_time_info[:time_allocated]} ms" \
           ", early: #{ann_time_info[:terminated_early]}, timeout: #{ann_time_info[:timeout_hit]}"
    puts "      delta / delta:           #{'%6.3f' % (ann_time_info[:time_used] - expected_time).abs} ms " \
           "/ #{'%6.3f' % (ann_time_info[:time_allocated] - expected_time).abs} ms"
  end

  def print_metrics(metrics)
    puts "increases in metrics: timeouts = #{metrics[:timeouts]}, time_count = #{metrics[:time_count]}, time_total = #{'%6.3f' %  metrics[:time_total]}"
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
    return ann_timeouts["count"].to_f, ann_time["count"].to_f, ann_time["sum"].to_f
  end

  def extract_metric(metrics, doc_name, name)
    metrics.get("content.proton.documentdb.matching.#{name}", {"documenttype" => doc_name})
  end

end
