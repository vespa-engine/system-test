# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'document_set'
require 'document'
require_relative 'async_profiler_helper'


class MassiveSummariesTest < PerformanceTest
  include AsyncProfilerHelper

  def initialize(*args)
    super(*args)
    @queryfile = selfdir + 'book_query.txt'
  end

  def setup
    super
    set_owner("andreer")
  end

  def prepare
    super
  end

  def test_summary_performance
    set_description("Test performance fetching and rendering extremely large summaries (400 hits, totalt 80MB).")
    deploy_app(SearchApp.new.sd(selfdir + "book.sd").
               search_dir(selfdir + "search").
               container(Container.new.search(Searching.new).jvmoptions("-verbose:gc -Xms16g -Xmx16g -XX:NewRatio=1 -XX:+PrintGCDetails")).
               threads_per_search(1))
    start

    node_file = download_file_from_s3("books.json.zst", vespa.adminserver)
    feed_params = { :localfile => true }
    feedfile(node_file, feed_params)

    container = vespa.container.values.first
    run_fbench2(container, @queryfile, {:runtime => 20, :clients => 1, :append_str => "&presentation.format=json"}) # warmup
    run_fbench2_with_async_profiler(container, @queryfile, {:runtime => 60, :clients => 1, :append_str => "&presentation.format=json"}, [], "json")
    run_fbench2(container, @queryfile, {:runtime => 20, :clients => 1, :append_str => "&presentation.format=cbor"}) # warmup
    run_fbench2_with_async_profiler(container, @queryfile, {:runtime => 60, :clients => 1, :append_str => "&presentation.format=cbor"}, [], "cbor")
  end

end
