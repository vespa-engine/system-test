# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'uri'

class FeedingWithBucketContentionTest < PerformanceTest

  def setup
    super
    set_owner('vekterli')
  end

  def teardown
    super
  end

  # Controls PerformanceTest-specific app generator distribution bits
  def distribution_bits
    16
  end

  def test_feeding_docs_with_bucket_contention
    set_description('Test feeding performance when feed has high affinity to specific ' +
                    'buckets instead of being evenly distributed. Feeds to a number of ' +
                    'locations (ID-specified groups) with many documents in sequence per ' +
                    'location. This triggers "worst-case" write lock contention against ' +
                    'buckets (amortized 1 bucket per distinct location).')
    # Test configuration rationale:
    #  - 16 distribution bits to avoid implicitly measuring overhead of bucket splitting.
    #  - Only 4 persistence threads to make persistence-level lock contention relatively
    #    _more_ expensive than it would be when feed is distributed across many threads.
    #  - 1000 docs per location to avoid hitting the bucket split limits (modulo those
    #    pigeon hole cases where multiple locations hash to the same bucket).
    deploy_app(
      SearchApp.new.
        container(
          Container.new('container').
            jvmoptions('-Xms8g -Xmx8g').
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new)).
        admin_metrics(Metrics.new).
        indexing('container').
        sd(selfdir + 'test.sd').
        storage(StorageCluster.new('search', 1).distribution_bits(16)).
        config(ConfigOverride.new('vespa.config.content.stor-filestor').
          #add('max_feed_op_batch_size', '1024'). # <- for manual testing, use feature flag on factory
          add('num_threads', '4').
          add('num_response_threads', '2')))
    @container = vespa.container.values.first
    compile_create_docs
    start
    # Initially feed with shuffled documents to measure baseline case, then re-feed docs sequentially.
    [true, false].each do |shuffle_feed|
      feed_docs_to_locations(locations: 500, docs_per_location: 1000, shuffle: shuffle_feed)
    end
    stop
  end

  def feed_docs_to_locations(locations:, docs_per_location:, shuffle:)
    puts "Feeding #{docs_per_location} docs per #{locations} locations. Shuffle prior to feeding: #{shuffle ? 'yes' : 'no'}"
    command = "#{@create_docs} -n #{locations} -d #{docs_per_location}#{shuffle ? ' -s' : ''}"
    run_stream_feeder(command, [parameter_filler('type', 'feed'),
                                parameter_filler('shuffled', shuffle.to_s)])
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    src_path = "#{selfdir}create_docs.cpp"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@create_docs} #{src_path}")
  end

end
