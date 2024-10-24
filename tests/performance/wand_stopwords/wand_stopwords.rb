# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/wand_performance/wand_performance_specs'
require 'pp'

class WandStopWordsTest < PerformanceTest

  def setup
    super
    set_owner('havardpe')
  end

  def initialize(*args)
    super(*args)
  end

  def prepare
    super
  end

  def deploy_and_start
    add_bundle(selfdir + 'MicroBmSearcher.java')
    searcher = Searcher.new('com.yahoo.test.MicroBmSearcher')
    deploy_app(
      SearchApp.new.
        sd(selfdir + 'wikimedia.sd').
        container(Container.new('mycc').
                    search(Searching.new.
                             chain(Chain.new('default', 'vespa').add(searcher))).
                    docproc(DocumentProcessing.new).
                    documentapi(ContainerDocumentApi.new)))
    start
  end

  def test_wand_with_stopwords
    set_description('Test performance and quality of Vespa Wand with stop words')
    deploy_and_start
    @doc_count = 1000
    feed_and_wait_for_docs('wikimedia', @doc_count, :file => selfdir + 'just-1k.json')
    assert_hitcount('yql=select title from wikimedia where true', @doc_count)
    measure_wand_quality
    feed_file('enwiki-20240801-pages.1M.jsonl.zst')
    measure_wand_quality
  end

  def max(a,b)
    a>b ? a : b
  end

  def min(a,b)
    a<b ? a : b
  end

  def measure_wand_quality
    counter = 0
    File.readlines(selfdir + 'squad2-questions.txt').each do |line|
      counter = counter + 1
      if ((counter % 100) != 0)
        next
      end
      line.gsub!(/\W/, ' ')
      q = "/search/?query=#{line}&hits=100"
      r = search(q)
      h = r.hit[0]
      quality = h.field['weakAndQuality']
      wantedHits = max(h.field['andHits'], min(100, h.field['orHits']))
      hitsFactor = (1000 * h.field['weakAndHits'] ) / wantedHits
      hitsFactor = hitsFactor / 1000.0
      puts "quality: #{quality} with #{h.field['weakAndHits']} hits, factor #{hitsFactor} for query: #{line}"
    end
  end

  def feed_file(feed_file)
    node_file = download_file(feed_file, vespa.adminserver)
    run_feeder(node_file, [], {:client => :vespa_feed_client,
                               :compression => 'none',
                               :localfile => true,
                               :silent => true,
                               :disable_tls => false})
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, 'wikipedia')
  end

  def teardown
    super
  end
end
