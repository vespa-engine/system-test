# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'document'
require 'document_set'

class JavaDispatchTest < SearchTest

  def setup
    set_owner('ovirtanen')
    set_description('Tests for java dispatcher regressions')

    @num_docs = 50
  end

  def teardown
    stop
  end

  def test_multiple_groups_with_single_node
    deploy_app(create_app(2,1))
    start
    generate_and_feed_docs

    hits_fd = fetch_hits(false)
    puts "fdispatch hits = #{hits_fd}"

    hits_i1 = fetch_hits(true)
    puts "internal dispatch hits 1 = #{hits_i1}"

    hits_i2 = fetch_hits(true, hits_i1)
    puts "internal dispatch hits 2 = #{hits_i2}"

    assert(hits_i1 != hits_i2,
      "Internal dispatcher should dispatch to different node groups in subsequent queries")
    assert(hits_i1 == hits_fd || hits_i2 == hits_fd,
      "One of the internal dispatcher results must equal the fdispatch result")
  end

  def test_group_with_multiple_nodes
    deploy_app(create_app(1,3))
    start
    generate_and_feed_docs

    hits_fd = fetch_hits(false)
    puts "fdispatch hits = #{hits_fd}"

    hits_in = fetch_hits(true)
    puts "internal dispatch hits = #{hits_in}"

    assert(hits_fd == hits_in, "Internal dispatcher result must equal the fdispatch result")

    grp_fd = fetch_grouped(false)
    puts "fdispatch grouping = #{grp_fd}"

    grp_in = fetch_grouped(true)
    puts "internal dispatch grouping = #{grp_in}"

    assert(grp_fd == grp_in, "Internal dispatcher result with groupings must equal the fdispatch result")

    window_fd = fetch_window(false)
    puts "Hits in fdispatch window: #{window_fd}"

    window_in = fetch_window(true)
    puts "Hits in internal dispatcher window: #{window_in}"
    assert(window_fd == window_in, "Internal dispatcher result window equal the one from fdispatch")
  end

  def test_multiple_groups_with_multiple_nodes
    deploy_app(create_app(2,2))
    start
    generate_and_feed_docs

    grp_in = fetch_grouped(true)
    puts "internal dispatch grouping = #{grp_in}"
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

  def fetch_hits(internal, different_than='')
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22%3B"
    query = "yql=#{yql}&nocache&dispatch.internal=#{internal}&tracelevel=5"
    puts "query: #{query}"

    retries = 5
    while retries > 1
      result = search(query)
      assert_result_hitcount(result, @num_docs)
      hits = result.hit.to_s

      if hits == different_than # dispatcher chose the same content node
        retries = retries - 1
        puts "Expected different hits, but received the same. Will retry another #{retries} times"
        sleep 1
      else
        assert(internally_dispatched?(result) == internal, "Internally dispatched should be #{internal}")
        return hits
      end
    end

    flunk("Failed to get a different result set")
  end

  def fetch_grouped(internal)
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22+%7C+all(group(f3)+each(output(count(),sum(f2))))%3B"
    query = "yql=#{yql}&nocache&dispatch.internal=#{internal}&tracelevel=5"
    puts "query: #{query}"

    result = search(query)
    groups = ""
    result.xml.each_element("group/grouplist") do |grp|
      groups = groups + grp.to_s
    end

    assert(internally_dispatched?(result) == internal, "Internally dispatched should be #{internal}")

    if internal
      dispatches = all_internal_dispatches(result)
      if dispatches.length > 1
        matches = / search group (\d+)/.match(dispatches[0])
        group = matches[1]
        rx = Regexp.compile(" search (?:group #{group}|path /#{group})")
        for d in 1..dispatches.length - 1 do
          assert(rx.match(dispatches[d]), "All dispatches should go to the same group -- expected to find group #{group} in '#{dispatches[d]}'")
        end
      end
    end

    return groups
  end

  def fetch_window(internal)
    query = "query=sddocname:test&nocache&dispatch.internal=#{internal}&tracelevel=5&sortspec=-f2&offset=8&hits=11"
    puts "query: #{query}"

    result = search(query)
    assert_equal(11, result.hit.length, "Expected 11 returned hits")
    assert_equal(internal, internally_dispatched?(result), "Internally dispatched should be #{internal}")

    return result.hit.to_s
  end

  def internally_dispatched?(result)
    matches = 0
    result.xml.each_element("meta/p/p/p") do |e|
      matches = matches + 1 if e.to_s =~ /<p>Dispatching internally to search group/
    end
    return matches > 0
  end

  def all_internal_dispatches(result)
    dispatches = []
    result.xml.each_element("meta/p/p/p") do |e|
      dispatches << e.to_s if e.to_s =~ /<p>Dispatching internally /
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
