# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'app_generator/container_app'
require 'document'
require 'document_set'

class ContainsAndMatchesTest < IndexedOnlySearchTest

  def setup
    set_owner('ovirtanen')
    set_description('Tests for contains/matches on fields in index|attribute combinations')

    @num_docs = 8
  end

  def teardown
    stop
  end

  def test_contains_and_matches
    deploy_app(app_definition)
    start
    generate_and_feed_docs

    @expected_warnings = {
      "f1-matches"  => "<p>Field 'f1' is indexed, non-literal regular expressions will not be matched</p>",
      "f2-contains" => "<p>Field 'f2' is an attribute, 'contains' will only match exactly (unless fuzzy is used)</p>",
      "f3-matches"  => "<p>Field 'f3' is indexed, non-literal regular expressions will not be matched</p>",
    }

    h1 = fetch_field_hits("f1")
    h2 = fetch_field_hits("f2")
    h3 = fetch_field_hits("f3")
    puts "      Op: contains contains matches  matches  matches  matches"
    puts "    Term: two      one two  two      one two  .wo      n.*wo"
    puts "--------+------------------------------------------------------"
    puts "ix      | #{h1}"
    puts "   attr | #{h2}"
    puts "ix+attr | #{h3}"
    assert_equal("..XX..XX ...X...X ..XX..XX ........ ........ ........", h1, "Index-only field result")
    assert_equal("..X..... ...X.... ..XX..XX ...X...X ..XX..XX ...X...X", h2, "Attribute-only field result")
    assert_equal("..XX..XX ...X...X ..XX..XX ........ ........ ........", h3, "Index and attribute field result")
  end

  def fetch_field_hits(field)
    hits = []
    for operation in [
      ['contains', "two"], ['contains', "one%20two"],
      ['matches', 'two'],  ['matches', 'one%20two'],
      ['matches', ".wo"], ['matches', 'n.%2awo']
    ] do
      hits.push(fetch_hits(field, operation[0], operation[1]))
    end
    hits.join(" ")
  end

  def app_definition
    SearchApp.new
    .container(
      Container.new
      .search(Searching.new)
      .docproc(DocumentProcessing.new)
      .documentapi(ContainerDocumentApi.new))
    .cluster(
      SearchCluster.new("mycluster")
      .sd(selfdir + "test.sd")
      .redundancy(1)
      .ready_copies(1)
      .group(NodeGroup.new(0, "mytopgroup").distribution("*").group(NodeGroup.new(0, "mygroup0").node(NodeSpec.new("node1", 0)))))
  end

  def fetch_hits(field, operator, term)
    query = "yql=select+*+from+sources+*+where+#{field}+#{operator}+%22#{term}%22%3B&hits=100&tracelevel=2&format=xml"
    result = search(query)
    traces_found = 0
    result.xml.each_element("meta/p/p") do |e|
      msg = e.to_s
      if msg =~ /<p>Field/
        expected = @expected_warnings["#{field}-#{operator}"]
        assert_equal(expected, msg, "Trace for [#{field} #{operator} #{term}] not as expected")
        traces_found = traces_found + 1
      end
    end
    if @expected_warnings.has_key?("#{field}-#{operator}") && traces_found < 1
      assert(false, "Trace for [#{field} #{operator} #{term}] did not contain expected warning")
    end
    to_match_string(result.hit)
  end

  def to_match_string(hits)
    bits = []
    for h in 0 ... @num_docs do
      bits[h] = '.'
    end
    for h in hits do
      di = h.field["documentid"]
      ix = di["id:test:test::".length, di.length].to_i
      bits[ix] = 'X'
    end
    bits.join("")
  end

  def generate_doc(idx)
    doc = Document.new("test", "id:test:test::#{idx}")

    words = []
    words.push("one")   if idx & 1 > 0
    words.push("two")   if idx & 2 > 0
    words.push("three") if idx & 4 > 0
    fv = words.join(" ")

    for f in 1 ..3 do
      doc.add_field("f#{f}", fv)
    end
    return doc
  end

  def generate_and_feed_docs
    docs = DocumentSet.new()
    for i in 0 ... @num_docs do
      docs.add(generate_doc(i))
    end
    feed_file = "#{dirs.tmpdir}/docs.json"
    docs.write_json(feed_file)
    feed(:file => feed_file)
  end

end
