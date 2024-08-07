# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'performance/fbench'
require 'pp'

class ContainerGcTest < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'gcapp'
    @queryfile = nil
    @bundledir= selfdir + 'java'
  end

  def setup
    set_owner('bjorncs')
    # Empty bundle containing searcher that just returns results to mock
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})
  end


  def test_container_search_performance_g1gc
    deploy_expand_vespa_home(@app)
    start
    vespa_destination_start
    set_description('Test basic search container with libyell and query parsing. ' +
                    'Uses a Simple Searcher with Mock Hits using G1GC')
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    @queryfile = dirs.tmpdir + "/queries.txt"
    container.write_queries(template: 'text:$words() AND text:$words() AND text:$words()', count: 1000000,
                            parameters: { "model.locale" => "en-US" }, filename: @queryfile)
    profiler_start
    run_fbench(container, 128, 60, [parameter_filler('legend', 'test_container_search_performance_g1gc'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))])
    profiler_report('test_container_search_performance_g1gc')
  end

end
