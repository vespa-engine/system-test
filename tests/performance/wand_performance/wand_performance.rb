# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/wand_performance/wand_performance_base'

class WandPerformanceTest < WandPerformanceTestBase

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def get_spec_label(spec)
    "type-#{spec.type}-clients-#{spec.clients}-wandhits-#{spec.wand_hits}-searchthreads-#{spec.search_threads}-doccount-#{spec.doc_count}-thresholdfactor-#{spec.threshold_factor}"
  end

  def get_parameter_fillers(spec)
    [parameter_filler("clients", spec.clients), parameter_filler("type", spec.type), parameter_filler("wandhits", spec.wand_hits), parameter_filler("searchthreads", spec.search_threads), parameter_filler("doccount", spec.doc_count), parameter_filler("thresholdfactor", spec.threshold_factor)]
  end

  def run_fbench_helper(spec)
    run_fbench(spec, get_parameter_fillers(spec))
  end

  def run_wand_benchmarks
    for spec_type in @wand_specs
      for search_threads in [1,4]
        run_fbench_helper(spec_type.new(1, 1000, search_threads, @default_doc_count))
      end
    end
  end

  def run_base_benchmarks
    for spec_type in @base_specs
      for search_threads in [1,4]
        run_fbench_helper(spec_type.new(1, 1000, search_threads, @default_doc_count))
      end
    end
  end

  def run_threshold_boost_factor_benchmarks
    for threshold_factor in [1.0, 1.2, 2.0, 4.0, 8.0]
      run_fbench_helper(ParallelWandSpec.new(1, 200, 1, @default_doc_count, "", threshold_factor))
    end
  end

  def test_vespa_wand_performance
    set_description("Test performance of Parallel Wand, Vespa Wand and brute force approaches using a dataset with some common and some rare terms")
    @wand_specs = [ParallelWandSpec, VespaWandSpec]
    @base_specs = [DotProductOperatorSpec, DotProductFeatureSpec, OrSpec]
    @all_specs = @wand_specs + @base_specs
    @default_doc_count = 1000000

    deploy_and_start

    feed({ :template => doc_template, :count => @default_doc_count })
    assert_hitcount("sddocname:test", @default_doc_count)
    run_wand_benchmarks
    run_base_benchmarks
    run_threshold_boost_factor_benchmarks
  end

end
