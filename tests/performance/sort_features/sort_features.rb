# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'uri'

class SortFeaturesPerfTest < PerformanceTest

  # Each variant is [label, rank profile, sortspec, extra query parameters].
  # The rank profiles and the features available for sorting are defined in test.sd.
  # Sorting on rank features alone does not activate ranking (first-phase is not evaluated),
  # only the sort features referenced in the sortspec are computed for each hit.
  VARIANTS = [
    # baselines: matching only, ranking with cheap and expensive first-phase, attribute sorting
    ['unranked',          'unranked',       nil,                                       {}],
    ['rank_simple',       'sorting_simple', nil,                                       {}],
    ['rank_complex',      'sorting',        nil,                                       {}],
    ['attr',              'sorting',        '-price',                                  {}],
    # sorting on a single rank feature of increasing cost
    ['feature_attr',      'sorting',        '-feature(price_attr)',                    {}],
    ['feature_simple',    'sorting',        '-feature(final_price)',                   {}],
    ['feature_complex',   'sorting',        '-feature(complex_score)',                 {}],
    ['feature_query',     'sorting',        '-feature(weighted)',
     { 'input.query(w_price)' => '0.25', 'input.query(w_pop)' => '0.002' }],
    # multi-level sorting combining rank features, attributes and [rank]
    ['feature_two',       'sorting',        '-feature(decade) -feature(complex_score)', {}],
    ['feature_then_attr', 'sorting',        '-feature(decade) -price',                 {}],
    ['attr_then_feature', 'sorting',        '+category -feature(final_price)',         {}],
    ['feature_and_rank',  'sorting_simple', '-feature(final_price) -[rank]',           {}],
  ]

  def setup
    super
    set_owner('arnej')
    @num_docs = 2000000
    # percentage of the corpus matched by the query
    @hit_percentages = [1, 10, 50, 75, 100]
  end

  def test_sort_features
    set_description('Test performance of sorting on rank features (sort-features) ' +
                    'for result sets of 1%, 10%, 50%, 75% and 100% of the corpus')
    app = SearchApp.new.sd(selfdir + 'test.sd')
    app.search.tune_searchnode({'requestthreads' => { 'search' => 32, 'persearch' => 4, 'resultprocessing' => 32 }})
    app.threads_per_search(4)
    deploy_app(app)
    @container = vespa.container.values.first
    compile_create_docs
    start

    start_memory_sampler
    begin
      memory_phase('feed')
      feed_docs
      memory_phase('validate')
      validate_hitcounts
      validate_sorting
      run_query_and_profile
    ensure
      stop_memory_sampler
    end
    report_memory_summary
  end

  # Proton memory usage is sampled once per second by a background thread during the
  # whole test. Samples are grouped into phases (feeding, validation and each fbench run),
  # and each report written gets the RSS stats of the current phase.
  MEMORY_SAMPLE_INTERVAL = 1.0

  def start_memory_sampler
    @proton = vespa.search['search'].first
    @proton_pid = @proton.get_pid
    @memory_lock = Mutex.new
    @memory_phases = []
    @memory_stop = false
    memory_phase('startup')
    @memory_sampler = Thread.new do
      Thread.current.report_on_exception = false
      until @memory_stop
        sample_proton_memory
        sleep MEMORY_SAMPLE_INTERVAL
      end
    end
  end

  def stop_memory_sampler
    return unless @memory_sampler
    @memory_stop = true
    @memory_sampler.join
    sample_proton_memory
  end

  # Returns { 'VmRSS' => bytes, 'VmHWM' => bytes } for proton, or nil if unavailable
  def read_proton_memory
    out = @proton.execute("grep -E '^(VmRSS|VmHWM):' /proc/#{@proton_pid}/status",
                          :noecho => true, :exceptiononfailure => false)
    values = {}
    out.to_s.each_line do |line|
      if line =~ /^(VmRSS|VmHWM):\s+(\d+)\s+kB/
        values[$1] = $2.to_i * 1024
      end
    end
    values.empty? ? nil : values
  rescue StandardError => e
    puts "Failed sampling proton memory: #{e.message}"
    nil
  end

  def sample_proton_memory
    values = read_proton_memory
    return unless values && values['VmRSS']
    @memory_lock.synchronize do
      @memory_phases.last[:samples] << values['VmRSS']
      @memory_hwm = values['VmHWM'] if values['VmHWM']
    end
  end

  def memory_phase(label)
    @memory_lock.synchronize do
      @memory_phases << { :label => label, :samples => [] }
    end
    sample_proton_memory
  end

  # A filler computing RSS stats of the current phase when the report is written
  def memory_filler
    Proc.new do |result|
      sample_proton_memory
      samples = @memory_lock.synchronize { @memory_phases.last[:samples].dup }
      unless samples.empty?
        result.add_metric('memory.proton.rss.max', samples.max)
        result.add_metric('memory.proton.rss.avg', samples.sum / samples.size)
        result.add_metric('memory.proton.rss.last', samples.last)
      end
    end
  end

  def mb(bytes)
    format('%.1f', bytes.to_f / (1024 * 1024))
  end

  def report_memory_summary
    phases = @memory_lock.synchronize { @memory_phases.reject { |p| p[:samples].empty? } }
    return if phases.empty?
    puts 'Proton memory usage (RSS MB) per phase:'
    puts format('  %-28s %8s %10s %10s %10s', 'phase', 'samples', 'min', 'avg', 'max')
    phases.each do |p|
      s = p[:samples]
      puts format('  %-28s %8d %10s %10s %10s', p[:label], s.size, mb(s.min), mb(s.sum / s.size), mb(s.max))
    end
    all = phases.flat_map { |p| p[:samples] }
    after_feed = phases.find { |p| p[:label] == 'validate' }
    puts "Proton RSS max sampled: #{mb(all.max)} MB, peak (VmHWM): #{mb(@memory_hwm || 0)} MB"
    write_report([parameter_filler('label', 'memory_summary'),
                  metric_filler('memory.proton.rss.max', all.max),
                  metric_filler('memory.proton.rss.avg', all.sum / all.size),
                  metric_filler('memory.proton.rss.after_feed', after_feed ? after_feed[:samples].first : 0),
                  metric_filler('memory.proton.rss.end', all.last),
                  metric_filler('memory.proton.rss.peak', @memory_hwm || 0)])
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    @container.execute("g++ -g -O3 -o #{@create_docs} #{selfdir}create_docs.cpp")
  end

  def feed_docs
    run_stream_feeder("#{@create_docs} -d #{@num_docs}", [parameter_filler('label', 'feed'), memory_filler])
  end

  def yql(hit_percentage)
    "select * from sources * where bucket < #{hit_percentage}"
  end

  def query_params(hit_percentage, variant)
    _, rank_profile, sortspec, extra = variant
    params = { 'yql' => yql(hit_percentage), 'ranking.profile' => rank_profile }
    params['sortspec'] = sortspec if sortspec
    params.merge(extra)
  end

  def get_query(hit_percentage, variant, extra = {})
    '/search/?' + URI.encode_www_form(query_params(hit_percentage, variant).merge(extra))
  end

  def expected_hits(hit_percentage)
    @num_docs * hit_percentage / 100
  end

  def validate_hitcounts
    @hit_percentages.each do |p|
      assert_hitcount(get_query(p, VARIANTS[0], { 'hits' => '0' }), expected_hits(p))
    end
  end

  # 'variant' is either a label from VARIANTS or a complete variant
  def do_search(variant, hit_percentage = 10)
    variant = VARIANTS.find { |v| v[0] == variant } unless variant.is_a?(Array)
    result = search(get_query(hit_percentage, variant, { 'hits' => '20' }))
    assert_nil(result.errorlist, "Unexpected error(s) for #{variant}: #{result.errorlist}")
    assert_equal(expected_hits(hit_percentage), result.hitcount)
    assert_equal(20, result.hit.size)
    result
  end

  def values(result, &block)
    result.hit.map { |hit| block.call(hit.field) }
  end

  def relevancies(result)
    values(result) { |f| f['relevancy'].to_f }
  end

  def final_price(f)
    f['price'].to_f * (1.0 - f['discount'].to_f)
  end

  # must match complex_score in test.sd
  def complex_score(f)
    year = f['year'].to_i
    Math.log(1.0 + f['popularity'].to_i) * f['rating'].to_f / (1.0 + [0, 2025 - year].max / 10.0) +
      (f['discount'].to_f > 0.275 ? 5.0 : 0.0) +
      Math.sqrt(f['price'].to_f) / 10.0
  end

  def assert_descending(list, msg)
    list.each_cons(2) do |a, b|
      assert(a >= b - 1e-6 * a.abs, "#{msg}: expected #{a} >= #{b} in #{list}")
    end
  end

  # Checks that pairs are sorted on the first element, then on the second element within ties
  def assert_sorted_pairs(pairs, first_ascending, msg)
    pairs.each_cons(2) do |(a1, a2), (b1, b2)|
      if a1 == b1
        assert(a2 >= b2 - 1e-6 * a2.abs, "#{msg}: expected #{a2} >= #{b2} in #{pairs}")
      else
        assert(first_ascending ? a1 < b1 : a1 > b1, "#{msg}: wrong order on first key in #{pairs}")
      end
    end
  end

  def validate_sorting
    prices = values(do_search('attr')) { |f| f['price'].to_f }
    assert_descending(prices, 'attr')
    assert_equal(prices, values(do_search('feature_attr')) { |f| f['price'].to_f })

    assert_descending(values(do_search('feature_simple')) { |f| final_price(f) }, 'feature_simple')
    assert_descending(values(do_search('feature_query')) { |f| 0.25 * f['price'].to_f + 0.002 * f['popularity'].to_f },
                      'feature_query')

    # sorting on a feature alone does not activate ranking
    assert_equal([0.0] * 20, relevancies(do_search('feature_complex')))
    # the top hits sorted on the first-phase expression as a sort feature must have the same
    # scores as the top hits from ranking
    assert_equal(relevancies(do_search('rank_complex')),
                 relevancies(do_search(['', 'sorting', '-feature(complex_score) -[rank]', {}])))
    assert_equal(relevancies(do_search('rank_simple')),
                 relevancies(do_search('feature_and_rank')))
    assert_descending(values(do_search('feature_and_rank')) { |f| final_price(f) }, 'feature_and_rank')

    # multi-level sorting; check on a small result set to get ties on the first level
    assert_sorted_pairs(values(do_search('feature_then_attr', 1)) { |f| [f['year'].to_i / 10, f['price'].to_f] },
                        false, 'feature_then_attr')
    assert_sorted_pairs(values(do_search('attr_then_feature', 1)) { |f| [f['category'], final_price(f)] },
                        true, 'attr_then_feature')
    assert_sorted_pairs(values(do_search('feature_two', 1)) { |f| [f['year'].to_i / 10, complex_score(f)] },
                        false, 'feature_two')
  end

  def run_query_and_profile
    @hit_percentages.each do |p|
      VARIANTS.each do |v|
        query_and_profile(p, v)
      end
    end
  end

  def query_and_profile(hit_percentage, variant)
    label = "#{variant[0]}_p#{hit_percentage}"
    local_query_file = dirs.tmpdir + "query_#{label}.txt"
    File.write(local_query_file, get_query(hit_percentage, variant) + "\n")
    container_query_file = copy_to_container(local_query_file)
    result_file = dirs.tmpdir + "fbench_result_#{label}.txt"
    fillers = [parameter_filler('label', label),
               parameter_filler('variant', variant[0]),
               parameter_filler('hit_percentage', hit_percentage),
               parameter_filler('sortspec', variant[2] || 'none'),
               memory_filler]
    memory_phase(label)
    profiler_start
    run_fbench2(@container,
                container_query_file,
                { :runtime => 20,
                  :clients => 1,
                  :append_str => '&hits=10&summary=minimal&timeout=20s',
                  :result_file => result_file },
                fillers)
    profiler_report(label)
    @container.execute("head -12 #{result_file}")
  end

  def copy_to_container(source_file)
    dest_dir = dirs.tmpdir + 'queries'
    @container.copy(source_file, dest_dir)
    dest_dir + '/' + File.basename(source_file)
  end

end
