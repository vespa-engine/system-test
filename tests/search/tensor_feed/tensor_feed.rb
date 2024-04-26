# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/tensor_feed/tensor_feed_base.rb'

class TensorFeedTest < IndexedStreamingSearchTest

  include TensorFeedTestBase

  def setup
    set_owner("geirst")
    @base_dir = selfdir + "tensor_feed/"
  end

  def test_tensor_json_feed
    set_description("Test feeding of tensor field and retrieval via search and visit")
    deploy_app(SearchApp.new.sd(@base_dir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 4, :file => @base_dir + "docs.json")

    search_docs = extract_docs(search("query=sddocname:test&format=json").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs(search_docs)

    visit_response = vespa.document_api_v1.visit(:selection => "test", :fieldSet => "test:[document]", :cluster => "search", :wantedDocumentCount => 10)
    puts "visit_response: #{visit_response}"
    visit_docs = extract_visit_docs(visit_response)
    puts "visit_docs: #{visit_docs}"
    assert_tensor_docs(visit_docs)

    feed(:file => @base_dir + "updates.json")
    search_docs = extract_docs(search("query=sddocname:test&format=json&nocache").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs_after_updates(search_docs)

    visit_response = vespa.document_api_v1.visit(:selection => "test", :fieldSet => "test:[document]", :cluster => "search", :wantedDocumentCount => 10)
    puts "visit_response: #{visit_response}"
    visit_docs = extract_visit_docs(visit_response)
    puts "visit_docs: #{visit_docs}"
    assert_tensor_docs_after_updates(visit_docs)
  end

  def test_tensor_json_feed_attribute
    set_description("Test feeding of tensor field with attribute aspect")
    deploy_app(SearchApp.new.sd(@base_dir + "attribute/test.sd"))
    run_tensor_json_feed_attribute
  end

  def test_tensor_json_feed_paged_attribute
    set_description("Test feeding of tensor field with paged attribute aspect")
    deploy_app(SearchApp.new.sd(@base_dir + "paged_attribute/test.sd"))
    run_tensor_json_feed_attribute
  end

  def run_tensor_json_feed_attribute
    # Tests that summary data is properly populated from attribute,
    # also after attribute has been saved and application has been
    # restarted, i.e.  attribute populated by loading it from disk,
    # not from replaying transaction log.
    start
    feed_and_wait_for_docs("test", 4, :file => @base_dir + "docs.json")

    search_docs = extract_docs(search("query=sddocname:test&format=json").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs(search_docs)

    node = vespa.search["search"].first
    node.trigger_flush
    node.stop
    node.start
    wait_for_hitcount("sddocname:test&nocache", 4)

    search_docs = extract_docs(search("query=sddocname:test&format=json").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs(search_docs)

    feed(:file => @base_dir + "updates.json")
    search_docs = extract_docs(search("query=sddocname:test&format=json").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs_after_updates(search_docs)
    node.trigger_flush
    node.stop
    node.start
    wait_for_hitcount("sddocname:test&nocache", 4)
    search_docs = extract_docs(search("query=sddocname:test&format=json").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs_after_updates(search_docs)
  end

  def assert_tensor_docs(docs)
    assert_nil(get_tensor_field(docs[0]))
    assert_tensor_field([], docs[1])
    assert_tensor_field([{'address'=>{'x'=>'a', 'y'=>'b'}, 'value'=>2.0},
                         {'address'=>{'x'=>'c', 'y'=>'d'}, 'value'=>3.0}], docs[2])
    assert_tensor_field([{'address'=>{'x'=>'a', 'y'=>'b'}, 'value'=>2.5},
                         {'address'=>{'x'=>'c', 'y'=>'d'}, 'value'=>3.5}], docs[3])
  end

  def assert_tensor_docs_after_updates(docs)
    assert_tensor_field([{'address'=>{'x'=>'a', 'y'=>'b'}, 'value'=>4.0},
                         {'address'=>{'x'=>'c', 'y'=>'d'}, 'value'=>5.0}], docs[0])
    assert_tensor_field([{'address'=>{'x'=>'a', 'y'=>'b'}, 'value'=>4.5},
                         {'address'=>{'x'=>'c', 'y'=>'d'}, 'value'=>5.5}], docs[1])
    assert_tensor_field([], docs[2])
    assert_nil(get_tensor_field(docs[3]))
  end

  def teardown
    stop
  end

end
