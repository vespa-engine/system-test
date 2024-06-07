# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document_set'
require 'environment'
require 'indexed_streaming_search_test'

class Refeed < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test re-feeding documents from vespa-visit.")
    @feed_file = dirs.tmpdir + "feed.tmp"
    @visit_file = "#{Environment.instance.vespa_home}/tmp/visit.tmp"
    @refeed_file = "#{Environment.instance.vespa_home}/tmp/refeed.tmp"
    @visit_file2 = "#{Environment.instance.vespa_home}/tmp/visit2.tmp"
    @numdocs = 0
  end

  def teardown
    stop
  end

  def test_refeed_documents
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    generate_documents
    feed_and_wait_for_docs("test", @numdocs, :file => @feed_file)
    check_search
    vespa.adminserver.execute("vespa-visit --xmloutput --fieldset=test:[document] > #{@visit_file}")
    vespa.adminserver.execute("cat #{@visit_file} | " +
                              "sed -e '1i<vespafeed>' -e '$a</vespafeed>' | " +
                              "sed -e '1i<?xml version=\"1.0\" encoding=" +
                              "\"UTF-8\" standalone=\"no\"?>'" +
                              " > #{@refeed_file}")
    vespa.adminserver.execute("vespa-feeder #{@refeed_file}")
    check_search
    vespa.adminserver.execute("vespa-visit --xmloutput --fieldset=test:[document] > #{@visit_file2}")
    check_visit_files
  end

  def check_search
    unless is_streaming
      assert_predicate_search('', '%7Ba:7%7D', ["1"])
      assert_predicate_search('%7Bb:c%7D', '', ["1"])
      assert_predicate_search('%7Bb:c,d:e%7D', '', [])
      assert_predicate_search('%7Bb:c,d:e%7D', '%7Ba:7%7D', ["1"])
    end

    assert_hitcount('query=string:foo', 1)
    assert_hitcount('query=int:1000000000', 1)
    assert_hitcount('query=long:9223372036854775807', 1)
    assert_hitcount('query=byte:127', 1)
    assert_hitcount('query=float:42.21', 1)
    assert_hitcount('query=double:123.456', 1)
    assert_hitcount('query=uri:yahoo', 1)
    assert_hitcount('query=array:foo', 1)
    assert_hitcount('query=wset:foo', 1)
  end

  def generate_documents
    docs = DocumentSet.new
    docs.add(generate_doc("1", "predicate",
              "a in [7..231] and true or b in [c] and d not in [e]"))
    docs.add(generate_doc("2", "string", "foo bar baz"))
    docs.add(generate_doc("3", "int", "1000000000"))
    docs.add(generate_doc("4", "long", "9223372036854775807"))
    docs.add(generate_doc("5", "byte", "127"))
    docs.add(generate_doc("6", "float", "42.21"))
    docs.add(generate_doc("7", "double", "123.456"))
    docs.add(generate_doc("8", "pos", "N37.374821;W122.057174"))
    docs.add(generate_doc("9", "raw", "baz qux quux"))
    docs.add(generate_doc("10", "uri",
              "http://shopping.yahoo-inc.com:8080/yahoo/path/shop?d=hab#frag1"))
    docs.add(generate_doc("11", "array", ["foo", "bar"]))
    docs.add(generate_doc("12", "map", { "foo" => "bar" }))
    docs.add(generate_doc("13", "wset", {"foo" => 10, "bar" => 20}))
    docs.add(generate_doc("14", "struct", {"string" => "foo"}))
    docs.write_json(@feed_file)
  end

  def generate_doc(id, field, content)
    @numdocs += 1
    Document.new("test", "id:test:test::#{id}").add_field(field, content)
  end

  def assert_predicate_search(attributes, range_attributes, expected_hits)
    result = search(get_query(attributes, range_attributes))
    assert_hitcount(result, expected_hits.size)
    result.sort_results_by("documentid")
    for i in 0...expected_hits.size
      exp_docid = "id:test:test::#{expected_hits[i]}"
      puts "Expects that hit[#{i}].documentid == '#{exp_docid}'"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
    end
  end

  def get_query(attributes, range_attributes)
    '?boolean.field=predicate&boolean.attributes=' + attributes +
      '&boolean.rangeAttributes=' + range_attributes + '&nocache'
  end

  def check_visit_files
    puts "sorted diff"
    vespa.adminserver.execute("cat #{@visit_file} |sort >#{@visit_file}.sort")
    vespa.adminserver.execute("cat #{@visit_file2}|sort >#{@visit_file2}.sort")
    vespa.adminserver.execute("diff #{@visit_file}.sort #{@visit_file2}.sort")
  end
end
