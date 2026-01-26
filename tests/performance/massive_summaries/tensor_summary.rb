# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require_relative 'async_profiler_helper'

class TensorSummary < PerformanceTest
  include AsyncProfilerHelper

  def initialize(*args)
    super(*args)
    @tensor_queryfile = selfdir + 'tensor_query.txt'
    @tensor_docs = "mips-data/paragraph_docs.400k.json"
    @num_docs = 3200
  end

  def setup
    super
    set_owner("andreer")
  end

  def test_tensor_summary_performance
    set_description("Test performance rendering large tensors in summary (768-dim Cohere Wiki float tensors, 3200 hits per query).")
    deploy_app(SearchApp.new.sd(selfdir + "paragraph.sd").
               search_dir(selfdir + "search").
               container(Container.new.search(Searching.new).jvmoptions("-verbose:gc -Xms16g -Xmx16g -XX:NewRatio=1 -XX:+PrintGCDetails")).
               threads_per_search(1))
    start

    full_file = download_file_from_s3(@tensor_docs, vespa.adminserver, "nearest-neighbor")
    subset_file = dirs.tmpdir + "paragraph_docs.3200.json"

    lines_to_extract = @num_docs + 1
    vespa.adminserver.execute("(head -#{lines_to_extract} #{full_file} | head -c -2; echo ''; echo ']') > #{subset_file}", :exceptiononfailure => true)

    feed_params = { :localfile => true }
    feedfile(subset_file, feed_params)

    container = vespa.container.values.first
    run_fbench2(container, @tensor_queryfile, {:runtime => 20, :clients => 1, :append_str => "&presentation.format=json"}) # warmup
    run_fbench2_with_async_profiler(container, @tensor_queryfile, {:runtime => 90, :clients => 1, :append_str => "&presentation.format=json"}, [parameter_filler("legend", "json")], "json")
    run_fbench2(container, @tensor_queryfile, {:runtime => 20, :clients => 1, :append_str => "&presentation.format=cbor"}) # warmup
    run_fbench2_with_async_profiler(container, @tensor_queryfile, {:runtime => 60, :clients => 1, :append_str => "&presentation.format=cbor"}, [parameter_filler("legend", "cbor")], "cbor")
  end

end
