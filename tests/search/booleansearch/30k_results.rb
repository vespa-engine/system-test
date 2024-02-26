# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'base64'

class Boolean30KResultsTest < IndexedOnlySearchTest
  DOCUMENT_COUNT = 15000

  def setup
    set_owner("bjorncs")
    set_description("Tests returning 30K results from a boolean query")
    @feed_file = dirs.tmpdir + "boolean_feed_30K.tmp"
  end

  def deploy_and_feed
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("test", 3 * DOCUMENT_COUNT, :file => @feed_file)
  end

  def teardown
    stop
  end

  def write_doc(file, id, predicate)
    doc = Document.new("test", "id:test:test::#{id}").
      add_field("predicate_field", predicate)
    file.write(doc.to_xml)
  end

  def write_value_documents(file)
    for i in 1..DOCUMENT_COUNT
      write_doc(file, "feature-#{i}", "feature1 in [true]")
      write_doc(file, "range-#{i}", "range in [100..199]")
      write_doc(file, "no-hit-#{i}", "range in [300..399]")
    end
  end

  def test_boolean_search_30k_hits
    File.open(@feed_file, "w") {|file| write_value_documents(file) }
    deploy_and_feed

    assert_search('%7Bfeature1:true%7D', '%7Brange:120%7D', 2 * DOCUMENT_COUNT)
  end

  def assert_search(attributes, range_attributes, expected_result_count)
    query = '&boolean.field=predicate_field&boolean.attributes=' + attributes +
            '&boolean.rangeAttributes=' + range_attributes +
            '&hits=0&nocache'
    result = search(query)
    assert_equal(expected_result_count, result.hitcount)
  end

end
