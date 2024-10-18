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
        sd(selfdir + 'wiki.sd').
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
    feed_and_wait_for_docs('wiki', @doc_count, :file => selfdir + 'feed.json.zst')
    assert_hitcount('sddocname:wiki', @doc_count)
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
      hitsFactor = (100 * h.field['weakAndHits'] ) / wantedHits
      puts "quality: #{quality} with hits factor #{hitsFactor} % for query: #{line}"
    end
  end

  def teardown
    super
  end
end
