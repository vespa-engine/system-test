# Private reason: Depends on pub data

require 'indexed_search_test'
require 'environment'

class HitVerification < SearchTest

  GD_DATADIR = 'pub/systemtests/performance/boolean/gd/'
  TARGETING_DATADIR = 'pub/systemtests/performance/boolean/targeting/'
  VESPA_PRE_FLUSH_HITS_FILE = "#{Environment.instance.vespa_home}/tmp/vespa-pre-flush-hits.txt"
  VESPA_POST_FLUSH_HITS_FILE = "#{Environment.instance.vespa_home}/tmp/vespa-post-flush-hits.txt"
  LIB_CONJUNCTION_HITS_FILE = "#{Environment.instance.vespa_home}/tmp/predicate-library-conjunction-hits.txt"
  LIB_INTERVALONLY_HITS_FILE = "#{Environment.instance.vespa_home}/tmp/predicate-library-intervalonly-hits.txt"

  def setup
    set_owner("bjorncs")
    set_description('Verifies the correctness of the boolean algorithms in Vespa and the Java predicate library
      (by asserting that the hits returned are identical). Using Targeting and GD data sets.')
    @nodeserver = @vespa.nodeproxies.values.first
  end

  def timeout_seconds
    # 5 hours
    3600*5
  end

  def nightly?
    true
  end

  def fetch_file(path, file_name)
    puts "Fetching " + file_name
    file = @nodeserver.fetchfile(path + file_name)
    @nodeserver.copy_remote_file_into_local_directory(file, dirs.tmpdir)
    @nodeserver.execute("mkdir -p #{dirs.tmpdir}")
    @nodeserver.execute("cp #{file} #{dirs.tmpdir}")
    dirs.tmpdir + File.basename(file)
  end

  # Targeting data - ~850k documents, ~120k queries
  # This test is disabled since it takes ~3000 seconds on factory
  # Enable the test when you want to verify that changes in boolean search algorithms does not impact the correctness.
  def ignored_test_targeting_huge
    @valgrind = false
    feed_file = fetch_file(TARGETING_DATADIR, 'targeting-feed.xml')
    query_file = fetch_file(TARGETING_DATADIR, 'targeting-queries-json-64b-all.txt')
    compare_hits(feed_file, query_file, 'targeting', 10)
  end

  # Targeting data - 100k documents - 1k queries
  def test_targeting_small
    @valgrind = false
    feed_file = fetch_file(TARGETING_DATADIR, 'targeting-feed.100k.xml')
    query_file = fetch_file(TARGETING_DATADIR, 'targeting-queries-json-64b-1000n.txt')
    compare_hits(feed_file, query_file, 'targeting', 10, true)
  end

  def test_gd
    @valgrind = false
    feed_file = fetch_file(GD_DATADIR, 'vespa.xml')
    query_file = fetch_file(GD_DATADIR, 'queries.json.txt')
    compare_hits(feed_file, query_file, 'gd', 8, true)
  end

  def compare_hit_files(file1, file2)
    puts "Comparing '#{file1}' with '#{file2}' using diff"
    @nodeserver.execute("diff #{file1} #{file2}", {:exceptiononfailure => true})
  end

  def compare_hits(feed_file, query_file, sd_name, arity, verify_index_seralization = false)
    run_vespa(feed_file, query_file, sd_name, verify_index_seralization)
    vespa.stop_base
    run_predicate_library(feed_file, query_file, LIB_CONJUNCTION_HITS_FILE, 'CONJUNCTION', arity)
    compare_hit_files(VESPA_PRE_FLUSH_HITS_FILE, LIB_CONJUNCTION_HITS_FILE)

    run_predicate_library(feed_file, query_file, LIB_INTERVALONLY_HITS_FILE, 'INTERVALONLY', arity)
    compare_hit_files(VESPA_PRE_FLUSH_HITS_FILE, LIB_INTERVALONLY_HITS_FILE)
    compare_hit_files(LIB_CONJUNCTION_HITS_FILE, LIB_INTERVALONLY_HITS_FILE)
  end

  def flush_and_restart(sd_name)
    hitcount = search("/search/?query=sddocname:#{sd_name}&nocache&hits=0").hitcount
    puts "#{hitcount} documents are indexed"
    search_node = vespa.search['search'].first
    search_node.trigger_flush
    search_node.restart
    wait_for_hitcount("query=sddocname:#{sd_name}&nocache", hitcount)
  end

  def run_vespa(feed_file, query_file, sd_name, verify_index_serialization)
    deploy_vespa_app(sd_name + '.sd')
    @nodeserver.feedfile(feed_file, {:localfile => true})
    run_vespa_queries(query_file, VESPA_PRE_FLUSH_HITS_FILE)
    if verify_index_serialization
      flush_and_restart(sd_name)
      run_vespa_queries(query_file, VESPA_POST_FLUSH_HITS_FILE)
      compare_hit_files(VESPA_PRE_FLUSH_HITS_FILE, VESPA_POST_FLUSH_HITS_FILE)
    end
  end

  def deploy_vespa_app(search_def_file)
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.HitsVerificationSearcher")
    app = SearchApp.new.
        sd(selfdir + search_def_file).
        search_dir(selfdir + "search"). # Include query profile
        container(
          Container.new.jetty(true).jvmargs('-DThreadedRequestHandler.timeout=9000').search(
            Searching.new.chain(Chain.new("default", "vespa").add(Searcher.new("com.yahoo.vespatest.HitsVerificationSearcher")))))
    deploy_app(app)
    start
  end

  def run_vespa_queries(query_file, output_file)
    query = "/search/?nocache&hits=30000&summary=minimal&jsonFile=#{query_file}&outputFile=#{output_file}"
    puts "Executing query #{query}"
    search(query)
  end

  def run_predicate_library(feed_file, query_file, output_file, algorithm, arity)
    @nodeserver.execute(
      "java -Xmx6g -cp #{Environment.instance.vespa_home}/lib/jars/predicate-search-jar-with-dependencies.jar " +
      "com.yahoo.search.predicate.benchmarks.HitsVerificationBenchmark " +
      "--arity #{arity} --query-format JSON --algorithm #{algorithm} " +
      "--feed-file #{feed_file} --query-file #{query_file} #{output_file}")
  end

  def teardown
    stop
  end
end
