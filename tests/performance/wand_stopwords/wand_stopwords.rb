# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/wand_performance/wand_performance_specs'
require 'pp'

class WandStopWordsTest < PerformanceTest

  def setup
    super
    set_owner('arnej')
  end

  def initialize(*args)
    super(*args)
  end

  def prepare
    super
  end

  def deploy_and_start
    significance_model = "https://data.vespa-cloud.com/tests/performance/significance_model/enwiki-20240801.json.zst"
    add_bundle(selfdir + 'MicroBmSearcher.java')
    searcher = Searcher.new('com.yahoo.test.MicroBmSearcher')
    deploy_app(
      SearchApp.new.
        sd(selfdir + 'wikimedia.sd').
        threads_per_search(1).
        container(Container.new.
                    search(Searching.new.
                             significance(Significance.new.model_url(significance_model)).
                             chain(Chain.new('default', 'vespa').add(searcher))).
                    docproc(DocumentProcessing.new).
                    documentapi(ContainerDocumentApi.new)))
    start
  end

  def test_wand_with_stopwords
    set_description('Test performance and quality of Vespa Wand with stop words')
    deploy_and_start
    if File.exist?(selfdir + 'just-1k.json')
      # for faster turnaround during development:
      doc_count = 1000
      feed_and_wait_for_docs('wikimedia', doc_count,
                             { :file => selfdir + 'just-1k.json',
                               :client => :vespa_feed_client
                             })
      assert_hitcount('yql=select title from wikimedia where true', doc_count)
      measure_wand_quality
    end
    doc_count = 1000000
    feed_file('enwiki-20240801-pages.1M.jsonl.zst')
    wait_for_hitcount('yql=select title from wikimedia where true', doc_count)
    measure_wand_quality
  end

  def max(a,b)
    a>b ? a : b
  end

  def min(a,b)
    a<b ? a : b
  end

  def measure_wand_quality
    andQ = []
    orQ = []
    waQ = []
    wa20Q = []
    wa05Q = []
    andH = []
    orH = []
    waH = []
    wa20H = []
    wa05H = []
    andT = []
    orT = []
    waT = []
    wa20T = []
    wa05T = []
    counter = 0
    q_file = download_file('squad2-questions.raw.141k.txt.zst', vespa.adminserver)
    vespa.adminserver.execute("zstdcat #{q_file} | head -n 1000 > #{q_file}.raw")
    vespa.adminserver.execute("mv #{q_file} #{selfdir}", :exceptiononfailure => false)
    (1..500).each do |counter|
      line = vespa.adminserver.execute("sed -n #{counter}p < #{q_file}.raw", :noecho => true)
      line.gsub!(/\W/, ' ')
      q = "/search/?query=#{line}&hits=100&timeout=100"
      r = search(q)
      h = r.hit[0]
      andQ.append(h.field['andQuality'])
      waQ.append(h.field['weakAndQuality'])
      wa20Q.append(h.field['weakAndQuality20'])
      wa05Q.append(h.field['weakAndQuality05'])
      andH.append(h.field['andHits'])
      orH.append(h.field['orHits'])
      waH.append(h.field['weakAndHits'])
      wa20H.append(h.field['weakAndHits20'])
      wa05H.append(h.field['weakAndHits05'])
      andT.append(h.field['andTime'])
      orT.append(h.field['orTime'])
      waT.append(h.field['weakAndTime'])
      wa20T.append(h.field['weakAndTime20'])
      wa05T.append(h.field['weakAndTime05'])
      quality = h.field['weakAndQuality']
      wantedHits = max(h.field['andHits'], min(100, h.field['orHits']))
      hitsFactor = (1000 * h.field['weakAndHits']) / wantedHits
      hitsFactor = hitsFactor / 1000.0
      orHitsFactor = (1000 * h.field['orHits']) / h.field['weakAndHits']
      orHitsFactor = orHitsFactor / 1000.0
      speedup = (1000 * h.field['orTime']) / h.field['weakAndTime']
      speedup = speedup.to_i / 1000.0
      puts "quality: #{quality} speedup: #{speedup} with #{h.field['weakAndHits']} hits, factors #{hitsFactor} / #{orHitsFactor} for query: #{line}"
    end
    sz = andQ.size
    puts "== Average and median over #{sz} results =="
    process("AND-recall",         "recall@100", andQ)
    process("WeakAnd-100-recall", "recall@100", waQ)
    process("WeakAnd-20-recall",  "recall@100", wa20Q)
    process("WeakAnd-5-recall",   "recall@100", wa05Q)

    process("AND-hits",         "hits", andH)
    process("WeakAnd-100-hits", "hits", waH)
    process("WeakAnd-20-hits",  "hits", wa20H)
    process("WeakAnd-5-hits",   "hits", wa05H)
    process("OR-hits",          "hits", orH)

    process("AND-ms",         "latency", andT)
    process("WeakAnd-100-ms", "latency", waT)
    process("WeakAnd-20-ms",  "latency", wa20T)
    process("WeakAnd-5-ms",   "latency", wa05T)
    process("OR-ms",          "latency", orT)
  end

  def feed_file(feed_file)
    node_file = download_file(feed_file, vespa.adminserver)
    feed({:file => node_file,
          :client => :vespa_feed_client,
          :compression => 'none',
          :localfile => true,
          :silent => true,
          :disable_tls => false})
    vespa.adminserver.execute("mv #{node_file} #{selfdir}", :exceptiononfailure => false)
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, 'wikipedia')
  end

  def process(legend, type, values)
    sz = values.size
    values.sort!
    report(legend, type, values[sz/2], values.sum / sz)
  end

  def report(legend, type, median, avg)
    puts "#{legend}: median #{median} with average #{avg}"
    write_report([parameter_filler('legend', legend),
                  parameter_filler('type', type),
                  metric_filler('median', median),
                  metric_filler('average', avg)])
  end

  def teardown
    super
  end
end
