# coding: utf-8
# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'http_client'
require 'performance_test'
require 'performance/fbench'
require 'pp'


class BasicContainer < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'app'
    @queryfile = nil
    @bundledir= selfdir + 'java'
  end

  def setup
    set_owner('bjorncs')
    # Empty bundle containing searcher that just returns results to mock
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})
  end

  def setup_and_deploy(app)
    deploy_expand_vespa_home(app)
    start
    vespa_destination_start
  end

  def benchmark_queries(template, yql, set_locale)
    setup_and_deploy(@app)
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    parameters = set_locale ? { "model.locale" => "en-US" } : { }
    @queryfile = dirs.tmpdir + "/queries.txt"
    container.write_queries(template: template, yql: yql, count: 1000000, parameters: parameters, filename: @queryfile)
    profiler_start
    run_fbench(container, 128, 60, [parameter_filler('legend', 'test_container_search_performance'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))])
    profiler_report('test_container_search_performance')
  end

  def test_container_search_performance
    set_description('Test basic search container with opennlp and simple query parsing. Uses a Simple Searcher with Mock Hits')
    benchmark_queries('text:$words() AND text:$words() AND text:$words()', false, true)
  end

  def test_lang_detect_performance
    set_description('Test basic search container with opennlp, language detection and simple query parsing. Uses a Simple Searcher with Mock Hits')
    template = "$pick(1,
      Yahoo became a public company via an initial public offering in April 1996 and its stock price rose 600% within two years.,
      1996 ging Yahoo mit 46 Angestellten an die Börse. 2009 arbeiteten insgesamt rund 13.500 Mitarbeiter für Yahoo.,
      À l'origine Yahoo! était uniquement un annuaire Web.,
      Yahoo! Next是一个展示雅虎新技术、新产品的场所，目前在测试阶段。,
      เดือนกรกฎาคม 2012 Yahoo! ก็ได้ประธานเจ้าหน้าที่บริหารคนใหม่ \"มาริสสา เมเยอร์\" อดีตผู้บริหารจาก Google มาทำหน้าที่พลิกฟื้นบริษัท,
      وفقًا لمزودي تحليلات الويب دائما كأليكسا وسميلارويب،وصل موقع ياهولأكثر من 7 مليارات مشاهدة شهريًا - حيث احتل المرتبة السادسة بين أكثر مواقع الويب زيارة على مستوى العالم في عام 2016.,
      야후!의 전신인 디렉터리 사이트는 1994년 1월에 스탠퍼드 대학교 출신의 제리 양과 데이비드 파일로가 만들었으며 회사는 1995년 3월 2일에 설립되었다.,
      日本では、ヤフー株式会社がYahoo!（後にベライゾンがアルタバに売却）とソフトバンクの合弁会社として1996年に設立した。,
      7 февраля 2000 года Yahoo.com подвергся DDoS атаке и на несколько часов приостановил работу.,
      אתר יאהו! הוא אחד מאתרי האינטרנט הפופולריים ביותר בעולם עם מעל 500 מיליון כניסות בכל יום)"
    benchmark_queries(template, false, false)
  end

  def test_container_yql_performance
    set_description('Test basic search container with opennlp and YQL query parsing. Uses a Simple Searcher with Mock Hits')
    benchmark_queries('select * from sources * where text contains "$words()" AND weightedSet(text, { ' + (['"$words()": 1'] * 10).join(', ') +' });', true, true)
  end

end
