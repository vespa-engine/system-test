# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require_relative 'async_profiler_helper'

class MapWset < PerformanceTest
  include AsyncProfilerHelper

  def initialize(*args)
    super(*args)
    @queryfile = selfdir + 'map_wset_query.txt'
  end

  def setup
    super
    set_owner("andreer")
  end

  def prepare
    super
    # Generate schema with many match-features to test rendering performance
    num_match_features = 200
    schema = File.read(selfdir + "map_wset.sd.template")
    functions = (0...num_match_features).map { |i| "    function f#{i}() { expression: random(#{i}) }" }.join("\n")
    features = (0...num_match_features).map { |i| "      f#{i}" }.join("\n")
    schema = schema.gsub("FUNCTIONS_PLACEHOLDER", functions).gsub("FEATURES_PLACEHOLDER", features)
    File.write(selfdir + "map_wset.sd", schema)
  end

  def test_map_wset_performance
    set_description("Test performance rendering maps, weighted sets, and matchfeatures (3.2k docs with large map/wset fields).")
    deploy_app(SearchApp.new.sd(selfdir + "map_wset.sd").
               search_dir(selfdir + "search").
               container(Container.new.search(Searching.new).jvmoptions("-verbose:gc -Xms16g -Xmx16g -XX:NewRatio=1 -XX:+PrintGCDetails")).
               threads_per_search(1))
    start

    data_file = dirs.tmpdir + "map_wset_docs.json"
    `python3 #{selfdir}generate_map_wset_data.py 3200 > #{data_file}`

    feed_params = { :localfile => true }
    feedfile(data_file, feed_params)

    container = vespa.container.values.first

    run_fbench2(container, @queryfile, {:runtime => 20, :clients => 1, :append_str => ""})

    test_duration = 60
    async_profiler_pid = start_async_profiler(container, test_duration)

    profiler_start
    run_fbench2(container, @queryfile, {:runtime => test_duration, :clients => 1, :append_str => ""})
    profiler_report("profile-summary")

    if async_profiler_pid
      collect_async_profiler_results(container, "map_wset")
    end
  end

end
