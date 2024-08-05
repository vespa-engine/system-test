# Copyright Vespa.ai. All rights reserved.
require 'performance/wand_performance/wand_performance_base'

class WandFilterPerformanceTest < WandPerformanceTestBase

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def get_spec_label(spec)
    "type-#{spec.type}-filter-#{spec.filter}"
  end

  def test_vespa_wand_performance
    set_description("Test filter performance (none (0%), 1%, 20%, and 90%) with Parallel Wand, Vespa Wand and brute force approaches for a data set with some common and some rare weighted terms")
    @specs = [ParallelWandSpec, VespaWandSpec, DotProductOperatorSpec, DotProductFeatureSpec, OrSpec]
    @doc_count = 1000000

    deploy_and_start

    feed({ :template => doc_template, :count => @doc_count })
    assert_hitcount("query=sddocname:test", @doc_count)

    # warmup
    run_fbench(@specs[0].new(8, 1000, 1, @doc_count, '50'), [], true)

    # benchmark
    for spec_type in @specs
      {'0%' => '', '1%' => '10', '20%' => '200', '90%' => '900'}.sort.each do |key, filter|
        run_fbench(spec_type.new(8, 1000, 1, @doc_count, filter),
                   [parameter_filler("filter", key), parameter_filler("type", spec_type.stype)])
      end
    end

  end

end
