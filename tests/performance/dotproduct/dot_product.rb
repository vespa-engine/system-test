# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class DotProduct < PerformanceTest

  def initialize(*args)
    super(*args)
    @sdfile = selfdir + "dotproduct.sd"
  end


  def setup
    super
    set_owner("geirst")
    set_description("Test dotproduct-feature vs dotproduct-operator on various fields.")
  end


  def doc_template
    wset = 1.upto(512).map { |i| "\"#{i}\": $ints(1, 32768)" } .join(', ')
    '{ "put": "id:test:dotproduct::$seq()", "fields": { ' +
      '"wset": {' + wset + '}, "wset_fast": {' + wset + '}, ' +
      '"array": [$ints(512, 32768)], "array_float": [$ints(512, 32768)] } }'
  end


  def test_DotProduct
    deploy_app(SearchApp.new.threads_per_search(1).sd(@sdfile).search_dir(selfdir + "search"))
    start

    feed({:template => doc_template, :count => 100000})

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    pairs = 1.upto(512).map { |i| "#{i}:$ints(1, 32768)" } .join(",")

    operatorqueries = dirs.tmpdir + 'operator_queries.txt'
    container.write_urls(path: '/search/?wand.tokens=', template: '{' + pairs + '}',
                         count: 10000, filename: operatorqueries)

    featurequeries = dirs.tmpdir + 'feature_queries.txt'
    container.write_urls(path: '/search/?rankproperty.dotProduct.dotproductitems=', template: '(' + pairs + ')',
                         count: 10000, filename: featurequeries)

    #WARMUP
    #DP_OPERATOR
    just_run_fbench(container, 1, 10, get_wand_query("wset_fast", "dp_wset_fast_operator"), operatorqueries)
    #just_run_fbench(container, 1, 10, get_wand_query("wset", "dp_wset_operator"), operatorqueries)

    #DP_FEATURE
    just_run_fbench(container, 1, 10, get_query("dp_wset_fast"), featurequeries)
    just_run_fbench(container, 1, 10, get_query("dp_wset"), featurequeries)
    just_run_fbench(container, 1, 10, get_query("dp_array"), featurequeries)
    just_run_fbench(container, 1, 10, get_query("dp_array_float"), featurequeries)

    runtime=30

    for clients in [1, 30] do
      #TEST OPERATOR
      #Normal attribute
      #run_fbench(container, clients, runtime, get_wand_query("wset", "dp_wset_operator"), operatorqueries, "wset_operator" )
      #Fast-search attribute
      run_fbench(container, clients, runtime, get_wand_query("wset_fast", "dp_wset_fast_operator"), operatorqueries, "wset_fast_operator" )

      #TEST FEATURE
      run_fbench(container, clients, runtime, get_query("dp_wset_fast"), featurequeries, "wset_fast_feature")
      run_fbench(container, clients, runtime, get_query("dp_wset"), featurequeries, "wset_feature")
      run_fbench(container, clients, runtime, get_query("dp_array"), featurequeries, "array_feature")
      run_fbench(container, clients, runtime, get_query("dp_array_float"), featurequeries, "array_float_feature")
    end
  end

  def get_query(rank_profile)
    "&query=sddocname:dotproduct&ranking.profile=#{rank_profile}&summary=minSummary&timeout=5s"
  end

  def get_wand_query(wand_field, rank_profile)
    "&wand.type=dotProduct&wand.field=#{wand_field}&summary=minSummary&ranking.profile=#{rank_profile}&timeout=5s"
  end

  def just_run_fbench(qrserver, clients, runtime, append_str, queries)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if !append_str.empty?
    fbench.query(queries)
  end

  def run_fbench(qrserver, clients, runtime, append_str, queries, legend)
    #append_str << "&hits=1"
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if !append_str.empty?
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

end
