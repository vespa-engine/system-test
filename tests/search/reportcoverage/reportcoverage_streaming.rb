# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'

class ReportCoverageStreaming < StreamingSearchTest

  def setup
    set_owner("balder")
    set_description("Check coverage reports are returned from search.")
  end

  def qrserver
    vespa.container.values.first || vespa.qrservers.values.first
  end

  def test_reportcoverage
    deploy_app(singlenode_streaming_2storage(selfdir+"covtest.sd"))
    start
    node = vespa.adminserver
    container = qrserver()
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out 10000 | vespa-feed-perf")
    puts "compile and feed output: #{output}"
    wait_for_hitcount("sddocname:covtest&streaming.selection=true", 10000, 5)
    assert_hitcount("coverage&streaming.selection=true", 10000)
    result = search("/?query=coverage&streaming.selection=true&format=json").json
    assert_equal(10000, result["root"]["fields"]["totalCount"])
    coverage = result["root"]["coverage"]
    puts coverage.to_s
    assert_equal(100, coverage["coverage"])
    assert_equal(10000, coverage["documents"])
    assert_equal(true, coverage["full"])
    assert_equal(1, coverage["nodes"])
    assert_equal(1, coverage["results"])
    assert_equal(1, coverage["resultsFull"])
  end

  def teardown
    stop
  end

end
