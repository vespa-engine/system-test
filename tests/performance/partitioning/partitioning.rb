# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'

class SearchPartitioningBase < PerformanceTest

  def initialize(*args)
    super(*args)
    @warmup = false
  end

  def doc_template
    # include each bitX with 0.5 propability
    bits = 16.downto(0).map { |b| " $include(0.5, bit#{b})" } .join("")
    '{ "put": "id:test:test::doc$seq()", "fields": { "title": "title$seq()' + bits + '", "body": "body$seq()' + bits * 100 + '", "id": $seq() } }'
  end

  def print_metrics
    node = vespa.search["search"].searchnode["row[0].column[0]"]
    metrics = node.get_total_metrics
    puts("Metrics for default rank profile:")
    pp metrics.extract(/[.]matching[.]default[.]/)
  end

  def setup
    super
    set_description("Test using multiple threads for matching")
    @valgrind = false
    @valgrind_opt = nil
  end

  def thread_scaling_test
    deploy_app(SearchApp.new.
               search_dir(selfdir + "search").
               cluster(SearchCluster.new.
                       sd(selfdir + "test.sd").
                       threads_per_search(16).
                       group(NodeGroup.new(0, nil).
                            default_nodes(2, 0))))
    start
    feed_and_wait_for_hitcount("title:title1", 1, { :template => doc_template, :count => 100000 })

    qrserver = @vespa.container.values.first
    @vespa.search["search"].searchnode.values.each do |searchnode|
      searchnode.trigger_flush
    end
    warmup(qrserver)
    for num_partitions in [1, 2, 4, 8, 16, 1024, 0]
      run_fbench_ntimes(qrserver, 1, 30, 1, [parameter_filler("num_partitions", num_partitions)],{:append_str => "&ranking=thread"+num_partitions.to_s})
    end
  end

  def teardown
    @valgrind = false
    @valgrind_opt = nil
    super
  end

end
