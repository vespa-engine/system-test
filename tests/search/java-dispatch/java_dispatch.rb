# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'document'
require 'document_set'

class JavaDispatchTest < SearchTest

  def setup
    set_owner('ovirtanen')
    set_description('Tests the Java dispatcher')

    @num_docs = 50
  end

  def teardown
    stop
  end

  def test_multiple_groups_with_single_node
    deploy_app(create_app(2,1))
    start
    generate_and_feed_docs

    hits_i1 = fetch_hits
    puts "dispatch hits 1 = #{hits_i1}"

    hits_i2 = fetch_hits(hits_i1)
    puts "dispatch hits 2 = #{hits_i2}"

    assert(hits_i1 != hits_i2,
      "Should dispatch to different node groups in subsequent queries")
  end

  def test_group_with_multiple_nodes
    deploy_app(create_app(1,3))
    start
    generate_and_feed_docs

    hits_in = fetch_hits
    puts "Dispatch hits = #{hits_in}"

    grp_in = fetch_grouped
    puts "dispatch grouping = #{grp_in}"

    window_in = fetch_window
    puts "Hits in dispatcher window: #{window_in}"
  end

  def test_multiple_groups_with_multiple_nodes
    deploy_app(create_app(2,2))
    start
    generate_and_feed_docs

    grp_in = fetch_grouped
    puts "Dispatch grouping = #{grp_in}"
  end

  def test_node_failure_error_reporting
    deploy_app(create_app(1,2))
    start
    generate_and_feed_docs

    code_in = fetch_empty_code
    puts "no results, nodes up: #{code_in}"
    assert_equal(200, code_in)

    stop_node_and_wait("mycluster", 0)

    code_in = fetch_empty_code
    puts "no results, one node down: #{code_in}"
    assert_equal(200, code_in)

    stop_node_and_wait("mycluster", 1)

    code_in = fetch_empty_code
    puts "no results, all nodes down: #{code_in}"
    assert_equal(503, code_in)
  end

  def create_app(groups, nodes)
    add_bundle(selfdir + "DispatchTestSearcher.java")
    searcher = Searcher.new("com.yahoo.test.DispatchTestSearcher")
    if groups > 1
      distribution = "1|*"
    else
      distribution = "*"
    end
    topgroup = NodeGroup.new(0, "mytopgroup").distribution(distribution)
    distkey = 0
    for g in 1..groups do
      nodegroup = NodeGroup.new(g-1, "mygroup#{g-1}")
      for n in 1..nodes do
        nodegroup.node(NodeSpec.new("node1", distkey))
        distkey = distkey + 1
      end
      topgroup.group(nodegroup)
    end

    ContainerApp.new
    .container(
      Container.new("mycc")
      .search(Searching.new.chain(Chain.new("default", "vespa").add(searcher)))
      .docproc(DocumentProcessing.new))
    .search(
      SearchCluster.new("mycluster")
      .sd(selfdir + "test.sd")
      .redundancy(2)
      .ready_copies(2)
      .group(topgroup))
  end

  def fetch_hits(different_than='')
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22%3B"
    query = "yql=#{yql}&nocache&tracelevel=5"
    puts "query: #{query}"

    retries = 10
    while retries > 1
      result = search(query)
      assert_result_hitcount(result, @num_docs)
      hits = result.hit.to_s

      if hits == different_than # dispatcher chose the same content node
        retries = retries - 1
        puts "Expected different hits, but received the same. Will retry another #{retries} times"
        sleep 1
      else
        return hits
      end
    end

    flunk("Failed to get a different result set")
  end

  def fetch_grouped
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22+%7C+all(group(f3)+each(output(count(),sum(f2))))%3B"
    query = "yql=#{yql}&nocache&tracelevel=5&format=xml"
    puts "query: #{query}"

    result = search(query)
    groups = ""
    result.xml.each_element("group/grouplist") do |grp|
      groups = groups + grp.to_s
    end

    dispatches = all_dispatches(result)
    if dispatches.length > 1
      matches = /to group (\d+)/.match(dispatches[0])
      group = matches[1]
      rx = Regexp.compile("to (?:group #{group}|path /#{group})")
      for d in 1..dispatches.length - 1 do
        assert(rx.match(dispatches[d]), "All dispatches should go to the same group -- expected to find group #{group} in '#{dispatches[d]}'")
      end
    end

    return groups
  end

  def fetch_window
    query = "query=sddocname:test&nocache&tracelevel=5&sortspec=-f2&offset=8&hits=11"
    puts "query: #{query}"

    result = search(query)
    assert_equal(11, result.hit.length, "Expected 11 returned hits")

    return result.hit.to_s
  end

  def fetch_empty_code
    query = "query=no_such_thing&nocache&tracelevel=5"
    puts "query: #{query}"

    result = search(query)
    return result.responsecode.to_i
  end

  def all_dispatches(result)
    dispatches = []
    result.xml.each_element("meta/p/p/p") do |e|
      dispatches << e.to_s if e.to_s =~ /<p>Dispatching to group/
    end
    return dispatches
  end

  def generate_doc(idx, f1, f2, f3)
    doc = Document.new("test", "id:test:test::#{idx}")
    doc.add_field("f1", f1)
    doc.add_field("f2", f2)
    doc.add_field("f3", f3)
    return doc
  end

  def generate_and_feed_docs
    docs = DocumentSet.new()
    for i in 0...@num_docs do
      docs.add(generate_doc(i, 'word', i, i % 5))
    end
    feed_file = "#{dirs.tmpdir}/docs.xml"
    docs.write_xml(feed_file)
    feed(:file => feed_file)
  end

end
