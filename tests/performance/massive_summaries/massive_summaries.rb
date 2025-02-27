# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'document_set'
require 'document'


class MassiveSummariesTest < PerformanceTest

  def initialize(*args)
    super(*args)
    @queryfile = selfdir + 'query.txt'
  end

  def setup
    super
    set_owner("andreer")
    feed_file = "books.json.zst"
    remote_file = "https://data.vespa-cloud.com/tests/performance/#{feed_file}"
    local_file = dirs.tmpdir + feed_file
    local_feed_file = dirs.tmpdir + "feed.json"
    cmd = "curl -o '#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`
    @feed_file = local_file
  end

  def prepare
    super
  end

  def run_custom_fbench(append_str, qrserver, clients, run_time, run_profiler)
    profiler_start if run_profiler
    run_fbench2(qrserver,
                @queryfile,
                {:runtime => run_time, :clients => clients, :append_str => append_str})
    profiler_report("profile-summary") if run_profiler
  end

  def test_summary_performance
    set_description("Test performance fetching and rendering extremely large summaries (400 hits, totalt 80MB).")
    deploy_app(SearchApp.new.sd(selfdir + "book.sd").
               container(Container.new.search(Searching.new).jvmoptions("-verbose:gc -Xms16g -Xmx16g -XX:NewRatio=1 -XX:+PrintGCDetails")).
               threads_per_search(1))
    start

    feed_params = { :dummy => :avoidgc}
    feedfile(@feed_file, feed_params)

    container = vespa.container.values.first
    run_custom_fbench("&presentation.timing=true", container, 1, 20, false)
    run_custom_fbench("&presentation.timing=true", container, 1, 60, true)
  end

  def teardown
    super
  end

end
