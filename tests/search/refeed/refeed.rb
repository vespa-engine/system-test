# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'environment'

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
    File.open(@feed_file, "w") {|file| write_documents(file) }
  end

  def write_documents(file)
    write_doc(file, "1", "predicate",
              "a in [7..231] and true or b in [c] and d not in [e]")
    write_doc(file, "2", "string", "foo bar baz")
    write_doc(file, "3", "int", "1000000000")
    write_doc(file, "4", "long", "9223372036854775807")
    write_doc(file, "5", "byte", "127")
    write_doc(file, "6", "float", "42.21")
    write_doc(file, "7", "double", "123.456")
    write_doc(file, "8", "pos", "N37.374821;W122.057174")
    write_doc(file, "9", "raw", "baz qux quux")
    write_doc(file, "10", "uri",
              "http://shopping.yahoo-inc.com:8080/yahoo/path/shop?d=hab#frag1")
    write_doc(file, "11", "array", ["foo", "bar"])
    write_doc(file, "12", "map", { "foo" => "bar" })
    write_doc(file, "13", "wset", [["foo", 10], ["bar", 20]])
    write_doc(file, "14", "struct", Struct.new(:string).new("foo"))
  end

  def write_doc(file, id, field, content)
    doc = Document.new("test", "id:test:test::#{id}").add_field(field, content)
    file.write(doc.to_xml())
    @numdocs += 1
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
