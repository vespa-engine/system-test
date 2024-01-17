# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'
require 'search/tensor_feed/tensor_feed_base.rb'

class TensorFeedHexTest < IndexedStreamingSearchTest

  include TensorFeedTestBase

  def setup
    set_owner("arnej")
    @base_dir = selfdir + "tensor_hex/"
  end

  def test_tensor_hex_feed
    set_description("Test hex format feeding of tensor field and retrieval via search and visit")
    deploy_app(SearchApp.new.sd(@base_dir + "test.sd").enable_document_api)
    start
    feed_and_wait_for_docs("test", 4, :file => @base_dir + "docs.json")

    search_docs = extract_docs(search("query=sddocname:test&format=json&format.tensors=long").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs(search_docs)

    visit_response = vespa.document_api_v1.visit(:selection => "test", :fieldSet => "test:[document]", :cluster => "search", :wantedDocumentCount => 10, "format.tensors" => "long")
    puts "visit_response: #{visit_response}"
    visit_docs = extract_visit_docs(visit_response)
    puts "visit_docs: #{visit_docs}"
    assert_tensor_docs(visit_docs)

    feed(:file => @base_dir + "updates.json")
    search_docs = extract_docs(search("query=sddocname:test&format=json&format.tensors=long&nocache").json)
    puts "search_docs: #{search_docs}"
    assert_tensor_docs_after_updates(search_docs)

    visit_response = vespa.document_api_v1.visit(:selection => "test", :fieldSet => "test:[document]", :cluster => "search", :wantedDocumentCount => 10, "format.tensors" => "long")
    puts "visit_response: #{visit_response}"
    visit_docs = extract_visit_docs(visit_response)
    puts "visit_docs: #{visit_docs}"
    assert_tensor_docs_after_updates(visit_docs)
  end

  def assert_tensor_docs(docs)
    expect_8 = [ nil,
                 [{'address'=>{'x'=>'0'}, 'value'=>0.0},
                  {'address'=>{'x'=>'1'}, 'value'=>0.0},
                  {'address'=>{'x'=>'2'}, 'value'=>0.0},
                  {'address'=>{'x'=>'3'}, 'value'=>0.0},
                  {'address'=>{'x'=>'4'}, 'value'=>0.0},
                  {'address'=>{'x'=>'5'}, 'value'=>0.0},
                  {'address'=>{'x'=>'6'}, 'value'=>0.0},
                  {'address'=>{'x'=>'7'}, 'value'=>0.0}],
                 [{'address'=>{'x'=>'0'}, 'value'=>1.0},
                  {'address'=>{'x'=>'1'}, 'value'=>2.0},
                  {'address'=>{'x'=>'2'}, 'value'=>3.0},
                  {'address'=>{'x'=>'3'}, 'value'=>4.0},
                  {'address'=>{'x'=>'4'}, 'value'=>5.0},
                  {'address'=>{'x'=>'5'}, 'value'=>6.0},
                  {'address'=>{'x'=>'6'}, 'value'=>7.0},
                  {'address'=>{'x'=>'7'}, 'value'=>8.0}],
                 [{'address'=>{'x'=>'0'}, 'value'=>1.0},
                  {'address'=>{'x'=>'1'}, 'value'=>-128.0},
                  {'address'=>{'x'=>'2'}, 'value'=>-1.0},
                  {'address'=>{'x'=>'3'}, 'value'=>0.0},
                  {'address'=>{'x'=>'4'}, 'value'=>127.0},
                  {'address'=>{'x'=>'5'}, 'value'=>17.0},
                  {'address'=>{'x'=>'6'}, 'value'=>42.0},
                  {'address'=>{'x'=>'7'}, 'value'=>-52.0}] ]
    expect_16 = [ nil,
                  [],
                  [{"address"=>{"x"=>"foo","y"=>"0"}, "value"=>100.0},
                   {"address"=>{"x"=>"foo","y"=>"1"}, "value"=>200.0},
                   {"address"=>{"x"=>"foo","y"=>"2"}, "value"=>300.0},
                   {"address"=>{"x"=>"foo","y"=>"3"}, "value"=>400.0},
                   {"address"=>{"x"=>"bar","y"=>"0"}, "value"=>500.0},
                   {"address"=>{"x"=>"bar","y"=>"1"}, "value"=>600.0},
                   {"address"=>{"x"=>"bar","y"=>"2"}, "value"=>700.0},
                   {"address"=>{"x"=>"bar","y"=>"3"}, "value"=>800.0}],
                  [{"address"=>{"x"=>"foo","y"=>"0"}, "value"=>0.0},
                   {"address"=>{"x"=>"foo","y"=>"1"}, "value"=>0.0},
                   {"address"=>{"x"=>"foo","y"=>"2"}, "value"=>0.0},
                   {"address"=>{"x"=>"foo","y"=>"3"}, "value"=>0.0},
                   {"address"=>{"x"=>"bar","y"=>"0"}, "value"=>0.0},
                   {"address"=>{"x"=>"bar","y"=>"1"}, "value"=>0.0},
                   {"address"=>{"x"=>"bar","y"=>"2"}, "value"=>0.0},
                   {"address"=>{"x"=>"bar","y"=>"3"}, "value"=>0.0}] ]

    assert_nil(get_tensor_field(docs[0], 'my_8_tensor'))
    assert_nil(get_tensor_field(docs[0], 'my_16_tensor'))

    assert_tensor_field(expect_8[1], docs[1], 'my_8_tensor')
    assert_tensor_field(expect_8[2], docs[2], 'my_8_tensor')
    assert_tensor_field(expect_8[3], docs[3], 'my_8_tensor')

    assert_tensor_field(expect_16[1], docs[1], 'my_16_tensor')
    assert_tensor_field(expect_16[2], docs[2], 'my_16_tensor')
    assert_tensor_field(expect_16[3], docs[3], 'my_16_tensor')
  end

  def assert_tensor_docs_after_updates(docs)
    expect_8 = [
      [{"address"=>{"x"=>"0"}, "value"=>-1.0},
       {"address"=>{"x"=>"1"}, "value"=>-2.0},
       {"address"=>{"x"=>"2"}, "value"=>-3.0},
       {"address"=>{"x"=>"3"}, "value"=>-4.0},
       {"address"=>{"x"=>"4"}, "value"=>-5.0},
       {"address"=>{"x"=>"5"}, "value"=>-6.0},
       {"address"=>{"x"=>"6"}, "value"=>-7.0},
       {"address"=>{"x"=>"7"}, "value"=>-8.0}],
      [{"address"=>{"x"=>"0"}, "value"=>0.0},
       {"address"=>{"x"=>"1"}, "value"=>0.0},
       {"address"=>{"x"=>"2"}, "value"=>0.0},
       {"address"=>{"x"=>"3"}, "value"=>0.0},
       {"address"=>{"x"=>"4"}, "value"=>0.0},
       {"address"=>{"x"=>"5"}, "value"=>0.0},
       {"address"=>{"x"=>"6"}, "value"=>0.0},
       {"address"=>{"x"=>"7"}, "value"=>0.0}],
      [{"address"=>{"x"=>"0"}, "value"=>0.0},
       {"address"=>{"x"=>"1"}, "value"=>0.0},
       {"address"=>{"x"=>"2"}, "value"=>0.0},
       {"address"=>{"x"=>"3"}, "value"=>0.0},
       {"address"=>{"x"=>"4"}, "value"=>0.0},
       {"address"=>{"x"=>"5"}, "value"=>0.0},
       {"address"=>{"x"=>"6"}, "value"=>0.0},
       {"address"=>{"x"=>"7"}, "value"=>0.0}]
    ]
    expect_16 = [
      [{"address"=>{"x"=>"foo","y"=>"0"}, "value"=>-1.0},
       {"address"=>{"x"=>"foo","y"=>"1"}, "value"=>-2.0},
       {"address"=>{"x"=>"foo","y"=>"2"}, "value"=>-3.0},
       {"address"=>{"x"=>"foo","y"=>"3"}, "value"=>-4.0},
       {"address"=>{"x"=>"bar","y"=>"0"}, "value"=>-5.0},
       {"address"=>{"x"=>"bar","y"=>"1"}, "value"=>-6.0},
       {"address"=>{"x"=>"bar","y"=>"2"}, "value"=>-7.0},
       {"address"=>{"x"=>"bar","y"=>"3"}, "value"=>-8.0}],
      [{"address"=>{"x"=>"foo","y"=>"0"}, "value"=>42.0},
       {"address"=>{"x"=>"foo","y"=>"1"}, "value"=>1048576.0},
       {"address"=>{"x"=>"foo","y"=>"2"}, "value"=>9.5367431640625e-07},
       {"address"=>{"x"=>"foo","y"=>"3"}, "value"=>-255.0},
       {"address"=>{"x"=>"bar","y"=>"0"}, "value"=>0.0},
       {"address"=>{"x"=>"bar","y"=>"1"}, "value"=>-0.0},
       {"address"=>{"x"=>"bar","y"=>"2"}, "value"=>1.1754943508222875e-38},
       {"address"=>{"x"=>"bar","y"=>"3"}, "value"=>3.3895313892515355e+38}],
      [{"address"=>{"x"=>"foo","y"=>"0"}, "value"=>100.0},
       {"address"=>{"x"=>"foo","y"=>"1"}, "value"=>200.0},
       {"address"=>{"x"=>"foo","y"=>"2"}, "value"=>300.0},
       {"address"=>{"x"=>"foo","y"=>"3"}, "value"=>400.0},
       {"address"=>{"x"=>"bar","y"=>"0"}, "value"=>500.0},
       {"address"=>{"x"=>"bar","y"=>"1"}, "value"=>600.0},
       {"address"=>{"x"=>"bar","y"=>"2"}, "value"=>700.0},
       {"address"=>{"x"=>"bar","y"=>"3"}, "value"=>800.0}]
    ]
    assert_tensor_field(expect_8[0], docs[0], 'my_8_tensor')
    assert_tensor_field(expect_8[1], docs[1], 'my_8_tensor')
    assert_tensor_field(expect_8[2], docs[2], 'my_8_tensor')
    assert_nil(get_tensor_field(docs[3], 'my_8_tensor'))
    assert_tensor_field(expect_16[0], docs[0], 'my_16_tensor')
    assert_tensor_field(expect_16[1], docs[1], 'my_16_tensor')
    assert_tensor_field(expect_16[2], docs[2], 'my_16_tensor')
    assert_nil(get_tensor_field(docs[3], 'my_16_tensor'))
  end

  def teardown
    stop
  end

end
