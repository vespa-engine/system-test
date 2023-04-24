# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'document'
require 'document_set'

class ProtobufSearchProtocolTest < SearchTest

  def setup
    set_owner('ovirtanen')
    set_description('Tests for search protocol over protobuf/jrt regressions')

    @num_docs = 25
  end

  def teardown
    stop
  end

  def test_basic_search
    deploy_app(app_definition)
    start
    generate_and_feed_docs

    hits_baseline = fetch_hits(false)
    puts "baseline hits = #{hits_baseline}"

    hits_protobuf = fetch_hits(true)
    puts "protobuf hits = #{hits_protobuf}"

    assert_equal(hits_baseline, hits_protobuf, "Protobuf results must equal baseline")

    grouped_baseline = fetch_grouped(false)
    puts "baseline grouped = #{grouped_baseline}"

    grouped_protobuf = fetch_grouped(true)
    puts "protobuf grouped = #{grouped_protobuf}"

    assert_equal(grouped_baseline, grouped_protobuf, "Grouped protobuf results must equal baseline")
  end

  def app_definition
    ContainerApp.new
    .container(Container.new.search(Searching.new).docproc(DocumentProcessing.new))
    .search(
      SearchCluster.new("mycluster")
      .sd(selfdir + "test.sd")
      .redundancy(1)
      .ready_copies(1)
      .group(NodeGroup.new(0, "mytopgroup")
        .distribution("*")
        .group(NodeGroup.new(0, "mygroup0")
          .node(NodeSpec.new("node1", 0))
          .node(NodeSpec.new("node1", 1)))))
  end

  def fetch_hits(with_protobuf)
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22%20order%20by%20f3%20asc,%20f2%20desc%3B"
    query = "yql=#{yql}#{request_params(with_protobuf)}"
    puts "query: #{query}"

    result = search(query)
    assert_result_hitcount(result, @num_docs)
    assert_protobuf_search(result)
    assert_protobuf_docsum(result)

    return result.hit.to_s
  end

  def fetch_grouped(with_protobuf)
    yql = "select+*+from+sources+*+where+f1+contains+%22word%22+%7C+all(group(f3)+each(output(count(),sum(f2))))%3B"
    query = "yql=#{yql}#{request_params(with_protobuf)}"
    puts "query: #{query}"

    result = search(query)
    assert_protobuf_search(result)
    groups = ""
    result.xml.each_element("group/grouplist") do |grp|
      groups = groups + grp.to_s
    end
    return groups
  end

  def request_params(with_protobuf)
    return "&dispatch.protobuf=#{with_protobuf}&nocache&tracelevel=5&format=xml"
  end

  def assert_protobuf_search(result)
    expected = true
    searches = 0
    result.xml.each_element("meta/p/p/p") do |e|
      searches = searches + 1 if e.to_s =~ /<p>Sending search request with jrt\/protobuf/
    end
    should = expected ? "should" : "should not"
    assert_equal(expected, searches > 0, "Request #{should} have used protobuf for searches")
  end

  def assert_protobuf_docsum(result)
    docsums = 0
    result.xml.each_element("meta/p/p/p") do |e|
      docsums = docsums + 1 if e.to_s =~ /<p>Sending \d+ summary fetch requests with jrt\/protobuf/
    end
    puts "docsum: " + result.to_s
    assert_equal(true, docsums > 0, "Request should have used protobuf for docsums")
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
