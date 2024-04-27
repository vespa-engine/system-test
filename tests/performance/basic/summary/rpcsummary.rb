# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'document_set'
require 'document'

class RpcSummaryTest < PerformanceTest

  def initialize(*args)
    super(*args)
    @queryfile = selfdir + 'query.txt'
    @feedbuffer = generate_feed
  end

  def generate_feed
    ds = DocumentSet.new()
    for doc_id in 0..10000
      doc = Document.new("test", "id:test:test::#{doc_id}")
      doc.add_field("id", doc_id)
      doc.add_field("f1", "approximately-fixed-string-#{doc_id}")
      ds.add(doc)
    end
    ds.to_json
  end

  def prepare
    super
  end

  def setup
    super
    set_owner("balder")
  end

  def run_custom_fbench(append_str, qrserver, clients, run_time, run_profiler)
    profiler_start if run_profiler
    run_fbench2(qrserver,
                @queryfile,
                {:runtime => run_time, :clients => clients, :append_str => append_str})
    profiler_report("profile-summary") if run_profiler
  end

  def test_summary_performance
    set_description("Test performance fetching many summaries.")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               search_dir(selfdir + "app").
               container(Container.new.search(Searching.new).jvmoptions("-verbose:gc -Xms16g -Xmx16g -XX:NewRatio=1 -XX:+PrintGCDetails")).
               threads_per_search(1))
    start
    feed_params = { :dummy => :avoidgc}
    feedbuffer(@feedbuffer, feed_params)

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    run_custom_fbench("&dispatch.summaries=true", container, 24, 20, false)
    run_custom_fbench("&dispatch.summaries=true", container, 24, 60, true)
  end

  def teardown
    super
  end

end
