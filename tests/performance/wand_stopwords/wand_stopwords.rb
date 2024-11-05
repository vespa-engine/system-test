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
    waA10Q = []
    waA02Q = []
    waD20Q = []
    waD05Q = []
    waXQ = []
    andH = []
    orH = []
    waH = []
    waA10H = []
    waA02H = []
    waD20H = []
    waD05H = []
    waXH = []
    andT = []
    orT = []
    waT = []
    waA10T = []
    waA02T = []
    waD20T = []
    waD05T = []
    waXT = []
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
      waA10Q.append(h.field['weakAndQualityA10'])
      waA02Q.append(h.field['weakAndQualityA02'])
      waD20Q.append(h.field['weakAndQualityD20'])
      waD05Q.append(h.field['weakAndQualityD05'])
      waXQ.append(h.field['weakAndQualityX'])
      andH.append(h.field['andHits'])
      orH.append(h.field['orHits'])
      waH.append(h.field['weakAndHits'])
      waA10H.append(h.field['weakAndHitsA10'])
      waA02H.append(h.field['weakAndHitsA02'])
      waD20H.append(h.field['weakAndHitsD20'])
      waD05H.append(h.field['weakAndHitsD05'])
      waXH.append(h.field['weakAndHitsX'])
      andT.append(h.field['andTime'])
      orT.append(h.field['orTime'])
      waT.append(h.field['weakAndTime'])
      waA10T.append(h.field['weakAndTimeA10'])
      waA02T.append(h.field['weakAndTimeA02'])
      waD20T.append(h.field['weakAndTimeD20'])
      waD05T.append(h.field['weakAndTimeD05'])
      waXT.append(h.field['weakAndTimeX'])
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
    process("WeakAnd-recall",     "recall@100", waQ)
    process("WeakAnd-A10-recall", "recall@100", waA10Q)
    process("WeakAnd-A2-recall",  "recall@100", waA02Q)
    process("WeakAnd-D20-recall", "recall@100", waD20Q)
    process("WeakAnd-D5-recall",  "recall@100", waD05Q)
    process("WeakAnd-X-recall",   "recall@100", waXQ)

    process("AND-hits",         "hits", andH)
    process("WeakAnd-hits",     "hits", waH)
    process("WeakAnd-A10-hits", "hits", waA10H)
    process("WeakAnd-A2-hits",  "hits", waA02H)
    process("WeakAnd-D20-hits", "hits", waD20H)
    process("WeakAnd-D5-hits",  "hits", waD05H)
    process("WeakAnd-X-hits",   "hits", waXH)
    process("OR-hits",          "hits", orH)

    process("AND-ms",         "latency", andT)
    process("WeakAnd-ms",     "latency", waT)
    process("WeakAnd-A10-ms", "latency", waA10T)
    process("WeakAnd-A2-ms",  "latency", waA02T)
    process("WeakAnd-D20-ms", "latency", waD20T)
    process("WeakAnd-D5-ms",  "latency", waD05T)
    process("WeakAnd-X-ms",   "latency", waXT)
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
