# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'environment'

class TensorInstructionBenchmarkTest < PerformanceTest

  COST = 'cost'
  IMPL_LONG = 'implementation'
  IMPL_SHORT = 'impl_short'
  BM_TYPE = 'benchmark_type'

  def setup
    super
    set_owner("arnej")
  end

  # TODO add limits and graphs and reenable when necessary.
  def ignore_test_instruction_benchmark
    set_description("Test performance of low-level tensor instructions")
    deploy_app(SearchApp.new.sd(selfdir+"dummy.sd"))
    searchnode = vespa.search['search'].first
    output = searchnode.execute("#{Environment.instance.vespa_home}/bin/vespa-tensor-instructions-benchmark --limit-implementations")
    parse_out(output)
  end

  def parse_out(output)
    bm_type = nil
    bm_codec = nil
    output.split("\n").each do |parse_line|
      if (parse_line =~ /^---/)
          bm_type = nil
          bm_codec = nil
      end
      if (parse_line =~ /Benchmark Case: \[(.*)\]/)
          bm_type = $1
      end
      if (parse_line =~ /Benchmarking encode.decode for: \[(.*)\]/)
          bm_codec = $1
      end
      if (parse_line =~ /^\s*([^(]*)[(]([^)]*)[)]:\s*([.0-9]*) us <(.*)>/)
          impl_long = $1
          impl_short = $2
          cost = $3
          sub_type = $4
          bm_codec = 'unknown' unless bm_codec
          bm_type = "#{sub_type} #{bm_codec}"
          write_report([metric_filler(COST, cost),
                        parameter_filler(IMPL_LONG, impl_long),
                        parameter_filler(IMPL_SHORT, impl_short),
                        parameter_filler(BM_TYPE, bm_type)])
      end
      if (parse_line =~ /^\s*([^(]*)[(]([^)]*)[)]:\s*([.0-9]*) us/)
          impl_long = $1
          impl_short = $2
          cost = $3
          bm_type = 'unknown' unless bm_type
          write_report([metric_filler(COST, cost),
                        parameter_filler(IMPL_LONG, impl_long),
                        parameter_filler(IMPL_SHORT, impl_short),
                        parameter_filler(BM_TYPE, bm_type)])
      end
    end
  end

  def teardown
    super
  end

end
