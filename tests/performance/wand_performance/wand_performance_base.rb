# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/wand_performance/wand_performance_specs'
require 'pp'

class WandPerformanceTestBase < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def initialize(*args)
    super(*args)
    @app = selfdir + "../wand_performance/elasticspapp"
    @warmup = false
    @fbench_runtime = 30
  end

  def prepare
    super
  end

  def deploy_and_start
    deploy(@app)
    start
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
    write_queries
  end

  # Generates a digit where 0's are common and other digits uncommon. Together with a first 8-value 
  # digit for weightsets, or a 128-valued 3-digit prefix for queries, which ensures uniqueness
  # of keys within each set/query, this yields 128k different keys with a non-uniform distribution. 
  def skewed_random
    "$pick(1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3)"
  end

  def write_queries
    @query_files = { "regular" => dirs.tmpdir + 'queries.txt', "dotproduct" => dirs.tmpdir + 'queries_dotproduct.txt' }

    pairs = 1.upto(8).map { |i| [4.times.map { |j| [4.times.map { |k| "#{i}#{j}#{k}#{skewed_random * 5}:$ints(1, 1000)" }] }] } .flatten.join(",")

    @container.write_urls(path: '/search/?wand.tokens=', template: '{' + pairs + '}',
                         count: 100000, filename: @query_files["regular"])

    @container.write_urls(path: '/search/?ranking.properties.dotProduct.tokens=', template: '(' + pairs + ')',
                         count: 100000, filename: @query_files["dotproduct"])
  end

  def doc_template
    wset = 1.upto(8).map { |i| "\"#{i}#{skewed_random * 7}\": $ints(1, 1000)" } .join(", ")
    '{ "put": "id:test:test::$seq()", "fields": { "features": { ' + wset + ' }, "filter": [$filter(1000, 1, 10, 100, 200, 500, 900)] } }'
  end

  def run_fbench(spec, custom_fillers, warmup=false)
    spec_label = get_spec_label(spec)
    puts "Runnning fbench: #{spec_label}"
    system_fbench = Perf::System.new(@container)
    system_fbench.start
    fbench = Perf::Fbench.new(@container, @container.name, @container.http_port)
    fbench.max_line_size = 100000
    fbench.runtime = @fbench_runtime
    fbench.clients = spec.clients
    fbench.append_str = spec.get_fbench_append_str

    profiler_start if !warmup
    fbench.query(@query_files[spec.get_query_file])
    system_fbench.end
    profiler_report(spec_label) if !warmup
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers) if !warmup
  end

  def teardown
    super
  end
end
