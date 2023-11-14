# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'environment'
require 'search/struct_and_map_types/struct_and_map_base'

class ImportedStructTest < SearchTest

  include StructAndMapBase

  def setup
    set_owner("toregge")
  end

  def create_app(grandparent)
    app = SearchApp.new
    if grandparent
      app.sd(selfdir + "imported_struct/nested/grandparent.sd", { :global => true })
      app.sd(selfdir + "imported_struct/nested/parent.sd", { :global => true })
    else
      app.sd(selfdir + "imported_struct/parent.sd", { :global => true })
    end
    app.sd(selfdir + "imported_struct/child.sd")
    app.container(Container.new.documentapi(ContainerDocumentApi.new).search(Searching.new))
    app
  end

  def deploy_and_start(grandparent)
    deploy_app(create_app(grandparent))
    start
  end

  def test_feed_and_retrieval_on_attribute_fields
    set_description("Test import of array/map of struct")
    deploy_and_start(false)
    run_feed_and_retrieval_on_attribute_fields(false)
  end

  def test_feed_and_retrieval_on_attribute_fields_nested_import
    set_description("Test nested import of array/map of struct")
    deploy_and_start(true)
    run_feed_and_retrieval_on_attribute_fields(true)
  end

  def test_matched_elements_only_in_document_summary
    set_description("Test that matched elements only are part of document summary")
    deploy_and_start(false)
    run_matched_elements_only_in_document_summary(false)
  end

  def test_matched_elements_only_in_document_summary_in_nested_import
    set_description("Test that matched elements only are part of document summary (nested import)")
    deploy_and_start(true)
    run_matched_elements_only_in_document_summary(true)
  end

  def feed_data_doc(documentapi, doctype, prefix, idsuffix, doc_template)
    doc = Document.new("#{doctype}", "id:test:#{doctype}::#{idsuffix}").
      add_field("#{prefix}elem_array", doc_template[:array]).
      add_field("#{prefix}elem_map", doc_template[:map]).
      add_field("#{prefix}str_int_map", doc_template[:simplemap])
    documentapi.put(doc)
  end

  def feed_data_docs(documentapi, doctype, prefix, doc_template_0, doc_template_1)
    feed_data_doc(documentapi, doctype, prefix, "0", doc_template_0) if doc_template_0
    feed_data_doc(documentapi, doctype, prefix, "1", doc_template_1) if doc_template_1
  end

  def feed_ref_doc(documentapi, doctype, parentdoctype, idsuffix)
    doc = Document.new("#{doctype}", "id:test:#{doctype}::#{idsuffix}").
      add_field("#{parentdoctype}_ref", "id:test:#{parentdoctype}::#{idsuffix}")
    documentapi.put(doc)
  end

  def feed_ref_docs(documentapi, doctype, parentdoctype)
    feed_ref_doc(documentapi, doctype, parentdoctype, "0")
    feed_ref_doc(documentapi, doctype, parentdoctype, "1")
  end

  def feed_docs(grandparent, doc_template_0, doc_template_1 = nil)
    documentapi = DocumentApiV1.new(vespa.adminserver.hostname, Environment.instance.vespa_web_service_port, self)
    if grandparent
      feed_data_docs(documentapi, "grandparent", "gp_", doc_template_0, doc_template_1)
      feed_ref_docs(documentapi, "parent", "grandparent")
    else
      feed_data_docs(documentapi, "parent", "", doc_template_0, doc_template_1)
    end
    feed_ref_docs(documentapi, "child", "parent")
  end

  def run_feed_and_retrieval_on_attribute_fields(grandparent)
    doc_template_0 = { :array => [elem("foo", 10), elem("bar", 20)],
                       :map => {"@foo" => elem("foo", 10), "@bar" => elem("bar", 20)},
                       :simplemap => {"@foo" => 10, "@bar" => 20} }
    doc_template_1 = { :array =>  [elem("foo", 10)],
                       :map => {"@foo" => elem("foo", 11), "@bar" => elem("bar", 20)},
                       :simplemap => {"@foo" => 11, "@bar" => 20} }

    feed_docs(grandparent, doc_template_0, doc_template_1)

    exp_doc0 = { :relevancy => 2222222.0, :array => doc_template_0[:array], :map => doc_template_0[:map], :intmap =>  doc_template_0[:simplemap] };
    exp_doc1 = { :relevancy => 1122222.0, :array => doc_template_1[:array], :map => doc_template_1[:map], :intmap =>  doc_template_1[:simplemap] };
    assert_result("query", "sddocname:child", [ exp_doc0, exp_doc1 ])
    assert_same_element("my_elem_array", "name contains 'foo', weight contains '10'", [ exp_doc0, exp_doc1 ])
    assert_same_element("my_elem_array", "name contains 'bar', weight contains '10'", [ ])
    assert_same_element("my_elem_array", "name contains 'bar', weight contains '20'", [ exp_doc0 ])
    assert_same_element("my_elem_map", "key contains '@bar', value.weight contains '20'", [ exp_doc0, exp_doc1 ])
    assert_same_element("my_elem_map", "key contains '@foo', value.weight contains '10'", [ exp_doc0 ])
    assert_same_element("my_elem_map", "key contains '@foo', value.weight contains '11'", [ exp_doc1 ])
    assert_same_element("my_elem_map", "key contains '@foo', value.weight contains '20'", [ ])
    assert_same_element("my_str_int_map", "key contains '@bar', value contains '20'", [ exp_doc0, exp_doc1 ])
    assert_same_element("my_str_int_map", "key contains '@foo', value contains '10'", [ exp_doc0 ])
    assert_same_element("my_str_int_map", "key contains '@foo', value contains '11'", [ exp_doc1 ])
    assert_same_element("my_str_int_map", "key contains '@foo', value contains '20'", [ ])
  end

  def run_matched_elements_only_in_document_summary(grandparent)
    doc_template = { :array => [elem("foo", 10), elem("bar", 20), elem("baz", 30)],
                     :map => {"@foo" => elem("foo", 10), "@bar" => elem("bar", 20), "@baz" => elem("baz", 30)},
                     :simplemap => {"@foo" => 10, "@bar" => 20, "@baz" => 30} }
    feed_docs(grandparent, doc_template)

    assert_same_element_summary("my_elem_array", "name contains 'bar', weight contains '20'", "filtered", "elem_array_filtered", [elem("bar", 20)])
    assert_same_element_summary("my_elem_map", "key contains '@bar', value.weight contains '20'", "filtered", "elem_map_filtered", {"@bar" => elem("bar", 20)})
    assert_same_element_summary("my_str_int_map", "key contains '@bar', value contains '20'", "filtered", "str_int_map_filtered", {"@bar" => 20})
    assert_same_element_single_summary("my_elem_array", "name contains 'bar'", "filtered", "elem_array_filtered", [elem("bar", 20)])
    assert_same_element_single_summary("my_elem_map", "key contains '@bar'", "filtered", "elem_map_filtered", {"@bar" => elem("bar", 20)})
    assert_same_element_single_summary("my_str_int_map", "key contains '@bar'", "filtered", "str_int_map_filtered", {"@bar" => 20})
  end

  def assert_same_element(field, same_element, exp_result)
    query = "select * from sources child where #{field} contains sameElement(#{same_element})"
    assert_result("yql", query, exp_result)
  end

  def assert_result(querytype, query, exp_result)
    form=[[querytype, query ],
          ["summary", "mysummary"],
          ["presentation.format", "json"]]
    encoded_form=URI.encode_www_form(form)
    puts "Endoded form: #{encoded_form}"
    result = search(encoded_form)
    assert_nil(result.errorlist)
    assert_equal(exp_result.size, result.hitcount)
    exp_result.size.times do |i|
      exp_hit = exp_result[i]
      hit = result.hit[i]
      my_elem_array = hit.field["my_elem_array"]
      my_elem_map = hit.field["my_elem_map"]
      my_str_int_map = hit.field["my_str_int_map"]
      relevancy = hit.field["relevancy"]
      puts "assert_result(): relevancy:       #{relevancy}"
      puts "assert_result(): my_elem_array:   #{my_elem_array}"
      puts "assert_result(): my_elem_map:     #{my_elem_map}"
      puts "assert_result(): my_str_int_map:  #{my_str_int_map}"
      assert_equal(exp_hit[:relevancy], relevancy)
      assert_equal(exp_hit[:array], my_elem_array)
      assert_equal(exp_hit[:map], my_elem_map)
      assert_equal(exp_hit[:intmap], my_str_int_map)
    end
  end

  def elem(name, weight)
    if name.nil?
      elem_weight(weight)
    else
      {"weight"=>weight, "name"=>name}
    end
  end

  def elem_weight(weight)
    {"weight"=>weight}
  end

  def teardown
    stop
  end
end
