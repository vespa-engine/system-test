require 'performance_test'
require 'app_generator/search_app'
require 'json_document_writer'

class WeightedSetFeedTest < PerformanceTest

  FIELD_TYPE = 'field_type'
  WSET = 'wset'
  WSET_SIZE = 'wset_size'
  FAST_SEARCH = 'fast_search'
  KEY_TYPE = 'key_type'
  LONG_TYPE = 'long'
  STRING_TYPE = 'string'

  def setup
    super
    set_owner('vekterli')
    @graphs = get_graphs
    @tainted = false
  end

  def teardown
    super
  end

  def with_json_feed(file_name)
    raise 'No block given' if not block_given?
    json_writer = JsonDocumentWriter.new(File.open(file_name, 'w'))
    begin
      yield json_writer
    ensure
      json_writer.close()
    end
  end

  def doc_id(n)
    "id:user:footype::#{n}"
  end

  def feed_initial_wsets(doc_count:, field_name:, key_type:, wset_size:, fast_search:)
    if @tainted
      puts 'Wiping existing index data on node to ensure previous tests do not pollute results'
      node = vespa.storage['search'].storage['0']
      node.stop_base
      node.clean_indexes
      node.start_base
    end
    puts '-----------'
    puts "Feeding #{doc_count} documents with weighted set field #{field_name} with #{wset_size} elements, fast-search=#{fast_search}"
    puts '-----------'
    feed_file = dirs.tmpdir + 'initial_feed.json'
    with_json_feed(feed_file) do |json|
      doc_count.times {|d|
        rng = Random.new(d)
        wset_contents = wset_size.times.map{|i| [rng.rand(10000000000), rng.rand(1000000000)] }.to_h
        json.put(doc_id(d), {
          field_name => wset_contents
        })
      }
    end
    puts 'Doing initial container warmup pass'
    feed(:file => feed_file, :route => '"combinedcontainer/chain.indexing null/default"')
    puts 'Doing actual backend feed pass'
    profiler_start
    run_feeder(feed_file, [parameter_filler(FIELD_TYPE, WSET),
                           parameter_filler(KEY_TYPE, key_type),
                           parameter_filler(WSET_SIZE, wset_size),
                           parameter_filler(FAST_SEARCH, fast_search.to_s)])
    profiler_report("wset_size=#{wset_size},fast_search=#{fast_search}")
    @tainted = true
  end

  def create_app
    # We only care about single node performance for this test.
    SearchApp.new.sd(selfdir + 'footype.sd').
    num_parts(1).redundancy(1).ready_copies(1).
    container(Container.new("combinedcontainer").
                            search(Searching.new).
                            docproc(DocumentProcessing.new).
                            gateway(ContainerDocumentApi.new)).
    generic_service(GenericService.new('devnull', "#{Environment.instance.vespa_home}/bin/vespa-destination --instant --silent 1000000000"))
  end

  class TestInstanceParams
    attr_reader :wset_size, :fast_search, :y_min, :y_max
    def initialize(wset_size, fast_search, y_min, y_max)
      @wset_size = wset_size
      @fast_search = fast_search
      @y_min = y_min
      @y_max = y_max
    end
  end

  def params(wset_size, fast_search, y_min, y_max)
    TestInstanceParams.new(wset_size, fast_search, y_min, y_max)
  end

  def parameter_combinations
    [
      params(10,     false, 17900, 23700),
      params(100,    false, 13000, 15000),
      params(1000,   false, 1850, 2060),
      params(10000,  false, 181, 211),
      params(100000, false, 15, 18),
      params(10,     true, 15000, 17250),
      params(100,    true, 2255, 2435),
      params(1000,   true, 220, 232),
      params(10000,  true, 18, 20),
      params(100000, true, 1.6, 1.75)
    ]
  end

  def get_graphs
    parameter_combinations.map do |p|
      {
        :x => FIELD_TYPE,
        :y => 'feeder.throughput',
        :title => "Throughput of weighted set feeding with #{p.wset_size} elements per set, key type long, fast search #{p.fast_search}",
        # TODO string type
        :filter => { WSET_SIZE => p.wset_size, KEY_TYPE => LONG_TYPE, FAST_SEARCH => p.fast_search.to_s},
        :historic => true,
        :y_min => p.y_min,
        :y_max => p.y_max
      }
    end.to_a
  end

  def string_attr_name(fast_search)
    fast_search ? 'wset_attr_string_fs' : 'wset_attr_string_nofs'
  end

  def long_attr_name(fast_search)
    fast_search ? 'wset_attr_long_fs' : 'wset_attr_long_nofs'
  end

  def test_wset_attribute_feed_performance
    set_description('Test feed performance of varying sizes of weightedset attributes, ' +
                    'with and without fast-search')
    deploy_app(create_app)
    start

    doc_count = 100_000
    parameter_combinations.each do |p|
      # Reduce document count for large cardinalities to keep test time reasonable.
      test_doc_count = doc_count / [(p.wset_size / 100), 1].max
      feed_initial_wsets(doc_count: test_doc_count, field_name: long_attr_name(p.fast_search),
                         key_type: LONG_TYPE, wset_size: p.wset_size, fast_search: p.fast_search)
    end
  end

end

