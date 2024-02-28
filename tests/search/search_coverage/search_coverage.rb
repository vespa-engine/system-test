# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'
require 'app_generator/search_coverage'
require 'document'
require 'document_set'

class SearchCoverageTest < IndexedOnlySearchTest

  def setup
    set_owner('ovirtanen')
    set_description('Search Coverage / Adaptive Timeout test')
    #test is very timeingsensitive so we disable valgrind.
    @valgrind = false

    @doc_ids = [
      # dist-key 0
      0,
      # dist-key 1
      1, 4,
      # dist-key 2
      2, 8, 15, 20,
      # dist-key 3
      5, 9, 11, 17, 19, 21, 22, 26
    ]

    @num_docs = @doc_ids.length
  end

  def teardown
    stop
  end

  def test_minimal_coverage
    run_case(0.1, 0.1, 0.2, 1, 25)
  end

  def test_minimal_coverage_with_extra_wait
    run_case(0.1, 0.4, 0.5, 3, 50)
  end

  def test_coverage_just_over_one_node_required
    run_case(0.3, 0.1, 0.2, 3, 50)
  end

  def test_coverage_three_quarters
    run_case(0.75, 0.1, 0.2, 7, 78)
  end

  def run_case(minimum_coverage, min_wait, max_wait, expected_count, expected_coverage)
    deploy_app(create_app(minimum_coverage, min_wait, max_wait))
    start
    generate_and_feed_docs
    fetch_hits("&ranking=quick", @num_docs, 100)
    fetch_hits("", expected_count, expected_coverage)
  end

  def create_app(minimum_coverage, min_wait, max_wait)
    SearchApp.new
    .container(
      Container.new
      .search(Searching.new.chain(Chain.new("default", "vespa")))
      .docproc(DocumentProcessing.new))
    .cluster(
      SearchCluster.new("mycluster")
      .sd(selfdir + "test.sd")
      .redundancy(1)
      .ready_copies(1)
      .threads_per_search(1)
      .group(NodeGroup.new(0, "mytopgroup")
        .distribution("*")
        .group(NodeGroup.new(0, "mygroup0")
          .node(NodeSpec.new("node1", 0))
          .node(NodeSpec.new("node1", 1))
          .node(NodeSpec.new("node1", 2))
          .node(NodeSpec.new("node1", 3))))
      .search_coverage(SearchCoverage.new
        .minimum(minimum_coverage)
        .min_wait_after_coverage_factor(min_wait)
        .max_wait_after_coverage_factor(max_wait)))
  end

  def fetch_hits(profile, expected_count, expected_coverage)
    q_start = Time.now
    result = search_with_timeout(5, "query=sddocname:test&nocache&hits=#{@num_docs}&format=json&ranking.softtimeout.enable=false#{profile}").json
    q_end = Time.now
    puts "Query completed in #{((q_end-q_start)*1000.0).to_i} ms"
    coverage = result["root"]["coverage"]
    degraded = coverage["degraded"]
    puts coverage.to_s
    assert_equal(expected_coverage, coverage["coverage"])
    assert_equal(expected_count, coverage["documents"])
    assert_equal(expected_coverage == 100, coverage["full"])
    if expected_coverage < 100
      assert_equal(false, degraded["timeout"])
      assert_equal(true,  degraded["adaptive-timeout"])
      assert_equal(false, degraded["non-ideal-state"])
    end
  end

  def generate_doc(idx, f1)
    doc = Document.new("test", "id:test:test::D#{idx}")
    doc.add_field("f1", f1)
    doc.add_field("weight", idx)
    return doc
  end

  def generate_and_feed_docs
    docs = DocumentSet.new()
    for i in @doc_ids do
      docs.add(generate_doc(i, 'document'))
    end
    feed_file = "#{dirs.tmpdir}/docs.xml"
    docs.write_xml(feed_file)
    feed(:file => feed_file)
  end

end
