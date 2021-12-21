# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'http_client'
require 'performance_test'
require 'performance/fbench'
require 'pp'


class BasicContainer < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'app'
    @queryfile = nil
    @bundledir= selfdir + 'java'
  end

  def setup
    set_owner('bjorncs')
    # Empty bundle containing searcher that just returns results to mock
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})
  end

  def setup_and_deploy(app)
    deploy_expand_vespa_home(app)
    start
  end

  def benchmark_queries(template, yql, set_locale)
    setup_and_deploy(@app)
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    parameters = set_locale ? { "model.locale" => "en-US" } : { }
    @queryfile = dirs.tmpdir + "/queries.txt"
    container.write_queries(template: template, yql: yql, count: 1000000, parameters: parameters, filename: @queryfile)
    profiler_start
    run_fbench(container, 128, 60, [parameter_filler('legend', 'test_container_search_performance'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))])
    profiler_report('test_container_search_performance')
  end

  def test_lang_detect_performance
    set_description('Test basic search container with opennlp, language detection and simple query parsing. Uses a Simple Searcher with Mock Hits')
    benchmark_queries('text:$words() AND text:$words() AND text:$words()', false, false)
  end

  def test_container_search_performance
    set_description('Test basic search container with opennlp and simple query parsing. Uses a Simple Searcher with Mock Hits')
    benchmark_queries('text:$words() AND text:$words() AND text:$words()', false, true)
  end

  def test_container_yql_performance
    set_description('Test basic search container with opennlp and YQL query parsing. Uses a Simple Searcher with Mock Hits')
    benchmark_queries('select * from sources * where text contains "$words()" AND text contains "$words()" AND text contains "$words()"', true, true)
  end

end
