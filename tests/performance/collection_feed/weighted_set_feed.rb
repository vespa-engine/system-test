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
    profiler_start
    run_feeder(feed_file, [parameter_filler(FIELD_TYPE, WSET),
                           parameter_filler(KEY_TYPE, key_type),
                           parameter_filler(WSET_SIZE, wset_size),
                           parameter_filler(FAST_SEARCH, fast_search.to_s)])
    profiler_report("wset_size=#{wset_size},fast_search=#{fast_search}")
  end

  def create_app
    # We only care about single node performance for this test.
    SearchApp.new.sd(selfdir + 'footype.sd').
    num_parts(1).redundancy(1).ready_copies(1).
    container(Container.new("combinedcontainer").
                            search(Searching.new).
                            docproc(DocumentProcessing.new).
                            gateway(ContainerDocumentApi.new))
  end

  def wset_test_sizes
    [10, 100, 1000, 10000, 100000]
  end

  def fast_search_combinations
    [false, true]
  end

  def get_graphs
    g = []
    fast_search_combinations.each do |fs|
      wset_test_sizes.each do |n|
        g << {
          :x => FIELD_TYPE,
          :y => 'feeder.avglatency',
          :title => "Average latency of weighted set feeding with #{n} elements per set, key type long, fast search #{fs}",
          # TODO string type
          :filter => { WSET_SIZE => n, KEY_TYPE => LONG_TYPE, FAST_SEARCH => fs.to_s},
          :historic => true
        }
      end
    end
    g
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
    wset_test_sizes.each do |n|
      # 10k docs with 100k elems would take forever with old O(n^2) behavior, so we scale the doc count down accordingly.
      test_doc_count = doc_count / [(n / 100), 1].max
      fast_search_combinations.each do |fs|
        feed_initial_wsets(doc_count: test_doc_count, field_name: long_attr_name(fs), key_type: LONG_TYPE, wset_size: n, fast_search: fs)
        # TODO enable string type test dimension once time complexity is fixed...!
        #feed_initial_wsets(doc_count: test_doc_count, field_name: string_attr_name(fs), key_type: STRING_TYPE, wset_size: n, fast_search: fs)
      end
    end
  end

end

