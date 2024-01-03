# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ReportCoverage < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check coverage reports are returned from search.")
    # Disable valgrind as test is timing sensitive
    @valgrind = false
    deploy_app(SearchApp.new.num_parts(2).sd(selfdir+"covtest.sd"))
    start
    vespa.adminserver.logctl("searchnode:proton.matching.matcher", "debug=on")
  end

  def test_reportcoverage_xml
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out 100000 | vespa-feed-perf")
    puts "compile and feed output: #{output}"
    wait_for_hitcount("sddocname:covtest", 100000, 5)
    assert_hitcount("coverage", 100000)

    result = search("/?query=coverage&format=xml")
    assert(result.xml.attribute("coverage-docs").to_s == "100000", "Expected 'coverage-docs' of 100000, got #{result.xml.attribute("coverage-docs")}.")
    assert(result.xml.attribute("coverage-nodes").to_s == "2", "Expected 'coverage-nodes' of 2, got #{result.xml.attribute("coverage-nodes")}.")
    assert(result.xml.attribute("coverage-full").to_s == "true", "Expected 'coverage-full' of true, got #{result.xml.attribute("coverage-full")}.")
    assert(result.xml.attribute("coverage").to_s == "100", "Expected 'coverage' of 100, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("results").to_s == "1", "Expected 'results' of 1, got #{result.xml.attribute("results")}.")
    assert(result.xml.attribute("results-full").to_s == "1", "Expected 'results-full' of 1, got #{result.xml.attribute("results-full")}.")

    result = search("/?query=coverage&ranking=lim&format=xml")
    puts("Got 'coverage-docs' of #{result.xml.attribute("coverage-docs")}.")
    assert(result.xml.attribute("coverage-full").to_s == "false", "Expected 'coverage-full' of false, got #{result.xml.attribute("coverage-full")}.")
    assert(result.xml.attribute("coverage").to_s.to_i >= 19, "Expected 'coverage' >= 19, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("coverage").to_s.to_i <= 23, "Expected 'coverage' <= 23, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("results").to_s == "1", "Expected 'results' of 1, got #{result.xml.attribute("results")}.")
    assert(result.xml.attribute("results-full").to_s == "0", "Expected 'results-full' of 0, got #{result.xml.attribute("results-full")}.")

    result = search("/?query=coverage&ranking=revlim&format=xml")
    puts("Got 'coverage-docs' of #{result.xml.attribute("coverage-docs")}.")
    assert(result.xml.attribute("coverage-full").to_s == "false", "Expected 'coverage-full' of false, got #{result.xml.attribute("coverage-full")}.")
    assert(result.xml.attribute("coverage").to_s.to_i >= 52, "Expected 'coverage' >= 52, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("coverage").to_s.to_i <= 65, "Expected 'coverage' <= 65, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("results").to_s == "1", "Expected 'results' of 1, got #{result.xml.attribute("results")}.")
    assert(result.xml.attribute("results-full").to_s == "0", "Expected 'results-full' of 0, got #{result.xml.attribute("results-full")}.")

    vespa.search['search'].searchnode.first.at(1).stop

    expcnt = 50155
    wait_for_hitcount("coverage", expcnt)

    result = search("/?query=coverage&format=xml")
    assert(result.xml.attribute("coverage-docs").to_s == expcnt.to_s, "Expected 'coverage-docs' of #{expcnt}, got #{result.xml.attribute("coverage-docs")}.")
    assert(result.xml.attribute("coverage-nodes").to_s == "1", "Expected 'coverage-nodes' of 1, got #{result.xml.attribute("coverage-nodes")}.")
    assert(result.xml.attribute("coverage-full").to_s == "false", "Expected 'coverage-full' of false, got #{result.xml.attribute("coverage-full")}.")
    assert(result.xml.attribute("coverage").to_s == "50", "Expected 'coverage' of 50, got #{result.xml.attribute("coverage")}.")
    assert(result.xml.attribute("results").to_s == "1", "Expected 'results' of 1, got #{result.xml.attribute("results")}.")
    assert(result.xml.attribute("results-full").to_s == "0", "Expected 'results-full' of 0, got #{result.xml.attribute("results-full")}.")
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def test_reportcoverage
    @valgrind = false
    node = vespa.adminserver
    container = qrserver()
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out 100000 | vespa-feed-perf")
    puts "compile and feed output: #{output}"
    wait_for_hitcount("sddocname:covtest", 100000, 5)
    assert_hitcount("coverage", 100000)
    result = search("/?query=coverage&format=json").json
    assert_equal(100000, result["root"]["fields"]["totalCount"])
    coverage = result["root"]["coverage"]
    puts coverage.to_s
    assert_equal(100, coverage["coverage"])
    assert_equal(100000, coverage["documents"])
    assert_equal(true, coverage["full"])
    assert_equal(2, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(1, coverage["resultsFull"])

    result = search("/?query=coverage&ranking=lim&format=json").json
    assert(23300 <= result["root"]["fields"]["totalCount"])
    assert(23450 >= result["root"]["fields"]["totalCount"])
    coverage = result["root"]["coverage"]
    puts coverage.to_s
    assert(19 <= coverage["coverage"])
    assert(23 >= coverage["coverage"])
    # This number depends on how the range search iterator (used by match-phase limiting) calculates approximation of number of hits.
    assert(18500 <= coverage["documents"])
    assert(23500 >= coverage["documents"])
    assert_equal(false, coverage["full"])
    assert_equal(2, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(0, coverage["resultsFull"])
    degraded = coverage["degraded"]
    assert_equal(true, degraded["match-phase"])
    assert_equal(false, degraded["timeout"])
    assert_equal(false, degraded["adaptive-timeout"])
    assert_equal(false, degraded["non-ideal-state"])

    result = search("/?query=coverage&ranking=revlim&format=json").json
    assert(65400 <= result["root"]["fields"]["totalCount"])
    assert(65600 >= result["root"]["fields"]["totalCount"])
    coverage = result["root"]["coverage"]
    degraded = coverage["degraded"]
    puts coverage.to_s
    assert(52 <= coverage["coverage"])
    assert(65 >= coverage["coverage"])
    # This number depends on how the range search iterator (used by match-phase limiting) calculates approximation of number of hits.
    assert(51500 <= coverage["documents"])
    assert(65500 >= coverage["documents"])
    assert_equal(false, coverage["full"])
    assert_equal(2, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(0, coverage["resultsFull"])
    assert_equal(true, degraded["match-phase"])
    assert_equal(false, degraded["timeout"])
    assert_equal(false, degraded["adaptive-timeout"])
    assert_equal(false, degraded["non-ideal-state"])

    result = search_base("/?query=coverage&ranking=slow&format=json&ranking.softtimeout.enable=true&ranking.softtimeout.factor=0.50&timeout=1.0").json
    coverage = result["root"]["coverage"]
    puts coverage.to_s
    assert(2000 <= result["root"]["fields"]["totalCount"])
    assert(50000 > result["root"]["fields"]["totalCount"])
    degraded = coverage["degraded"]
    assert(2 <= coverage["coverage"])
    assert(50 > coverage["coverage"])
    assert(2000 < coverage["documents"])
    assert(50000 > coverage["documents"])
    assert_equal(false, coverage["full"])
    assert_equal(2, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(0, coverage["resultsFull"])
    assert_equal(false, degraded["match-phase"])
    assert_equal(true, degraded["timeout"])
    assert_equal(false, degraded["adaptive-timeout"])
    assert_equal(false, degraded["non-ideal-state"])
    sleep(1)
    metrics = JSONMetrics.new(container.get_state_v1_metrics())
    assert_equal(2, metrics.get_all("degraded_queries", {"chain"=>"vespa", "reason"=>"match_phase"})["values"]["count"])
    assert_document_coverage(metrics, 80)

    vespa.search['search'].searchnode.first.at(1).stop

    expcnt = 50155
    # NB: time out in less than 60 seconds which is the metrics reporting window size
    wait_for_hitcount("coverage", expcnt, 30)
    result = search("/?query=coverage&format=json").json
    assert_equal(expcnt, result["root"]["fields"]["totalCount"])
    coverage = result["root"]["coverage"]
    degraded = coverage["degraded"]
    puts coverage.to_s
    assert_equal(50, coverage["coverage"])
    assert_equal(expcnt, coverage["documents"])
    assert_equal(false, coverage["full"])
    assert_equal(1, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(0, coverage["resultsFull"])
    assert_equal(false, degraded["match-phase"])
    assert_equal(true, degraded["timeout"])
    assert_equal(false, degraded["adaptive-timeout"])
    assert_equal(false, degraded["non-ideal-state"])
    sleep(1)
    metrics = JSONMetrics.new(container.get_state_v1_metrics())
    assert_equal(3, metrics.get_all("degraded_queries", {"chain"=>"vespa", "reason"=>"timeout"})["values"]["count"])
    assert_document_coverage(metrics, 80)
  end

  def assert_document_coverage(metrics, min_coverage_percentage)
    documents_covered = metrics.get_all("documents_covered", {"chain"=>"vespa"})["values"]["count"]
    documents_total = metrics.get_all("documents_total", {"chain"=>"vespa"})["values"]["count"]
    assert(min_coverage_percentage > (documents_covered / documents_total))
  end

  def teardown
    stop
  end

end
