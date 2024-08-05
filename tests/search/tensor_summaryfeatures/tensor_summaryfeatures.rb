# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class TensorSummaryFeatureTest < IndexedStreamingSearchTest

  def setup
    set_owner("lesters")
  end

  def test_tensor_in_summaryfeatures
    set_description("Test that tensors are surfaced correctly in summaryfeatures")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")

    search_doc = search("query=sddocname:test&format=json&format.tensors=long&ranking=test").json

    debug_attribute_and_summaryfeature(search_doc, 'indexed_tensor')
    debug_attribute_and_summaryfeature(search_doc, 'mapped_tensor')
    debug_attribute_and_summaryfeature(search_doc, 'mixed_tensor')

    assert_attribute_and_summaryfeature(search_doc, 'indexed_tensor')
    assert_attribute_and_summaryfeature(search_doc, 'mapped_tensor')
    assert_attribute_and_summaryfeature(search_doc, 'mixed_tensor')
  end

  def test_tensor_searcher_access
    add_bundle(selfdir+"TensorAccessingSearcher.java")

    set_description("Test that tensors are accessible in searchers")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")

    assert_query_no_errors("query=sddocname:test&format=json&ranking=test")

  end

  def debug_attribute_and_summaryfeature(doc, field)
    puts "Attribute #{field}: " + get_attribute(doc, field).to_s
    puts "Summaryfeature #{field}: " + get_summaryfeature(doc, field).to_s
  end

  def assert_attribute_and_summaryfeature(doc, field)
    attribute_field = get_attribute(doc, field)
    summaryfeature_field = get_summaryfeature(doc, field)
    assert_tensor_cells(attribute_field['cells'], summaryfeature_field['cells'])
  end

  def get_attribute(doc, field)
    return doc['root']['children'][0]['fields'][field]
  end

  def get_summaryfeature(doc, field)
    return doc['root']['children'][0]['fields']['summaryfeatures']["output_#{field}"]
  end

  def teardown
    stop
  end

end
