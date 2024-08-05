# Copyright Vespa.ai. All rights reserved.
require 'search/parent_child/parent_child_test_base'

class ReferencedTensorTest < ParentChildTestBase

  def setup
    set_owner("toregge")
    @test_dir = "referenced_tensor"
  end

  def deploy_and_start
    app = SearchApp.new.sd(get_sub_test_path("campaign.sd"), { :global => true }).sd(get_test_path("ad.sd"))
    app.sd(get_sub_test_path("grandcampaign.sd"), { :global => true }) if is_grandparent_test
    deploy_app(app)
    start
  end

  def test_imported_tensor_fields
    set_description("Test imported tensor fields")
    run_imported_tensor_fields_test("parent", "campaign")
  end

  def test_imported_grandparent_tensor_fields
    set_description("Test imported grandparent tensor fields")
    run_imported_tensor_fields_test("grandparent", "grandcampaign")
  end

  def run_imported_tensor_fields_test(sub_test_dir, root_type)
    @sub_test_dir = sub_test_dir
    deploy_and_start
    feed_and_wait_for_docs("campaign", 2, :file => get_sub_test_path("campaign-docs.json"))
    feed_and_wait_for_docs("ad", 5, :file => get_test_path("ad-docs.json"))
    assert_campaign_ref_fields(["id:test:campaign::0",
                                "id:test:campaign::1",
                                "id:test:campaign::2",
                                nil, nil])
    assert_relevances(root_type, [10209120.0, 50621240.0])
    assert_relevances("ad", [10209120.0, 50621241.0, 2.0, 3.0, 4.0])

    indexed_tensors = [{"type"=>"tensor(x[2])", "values"=>[1,2]}, {"type"=>"tensor(x[2])", "values"=>[5,6]}]
    mapped_tensors = [{"type"=>"tensor(x{})", "cells"=>{"0"=>3.0,"1"=>4.0}},{"type"=>"tensor(x{})", "cells"=>{"0"=>7.0,"1"=>8.0}}]
    assert_tensor_fields(root_type, "indexed_tensor", indexed_tensors)
    assert_tensor_fields(root_type, "mapped_tensor", mapped_tensors)
    feed(:file => get_test_path("ad-updates.json"))
    assert_campaign_ref_fields([nil, nil,
                                "id:test:campaign::0",
                                "id:test:campaign::1",
                                "id:test:campaign::2"])
    assert_relevances("ad", [0.0, 1.0, 10209122.0, 50621243.0, 4.0])
    assert_tensor_fields("ad", "my_indexed_tensor",
                         [nil, nil, indexed_tensors[0], indexed_tensors[1], nil]);
    assert_tensor_fields("ad", "my_mapped_tensor",
                         [nil, nil, mapped_tensors[0], mapped_tensors[1], nil]);
  end

  def assert_campaign_ref_fields(exp_campaign_refs)
    result = search("query=sddocname:ad&presentation.format=json&ranking=unranked")
    assert_field_values(result, "campaign_ref", exp_campaign_refs)
  end

  def assert_relevances(doc_type, exp_relevances)
    result = search("query=sddocname:#{doc_type}&presentation.format=json&ranking=default&ranking.features.query(qi)={{x:0}:100,{x:1}:1}&ranking.features.query(qm)={{x:0}:300,{x:1}:3}")
    assert_field_values(result, "relevancy", exp_relevances)
  end

  def assert_tensor_fields(doc_type, field_name, exp_tensors)
    result = search("query=sddocname:#{doc_type}&presentation.format=json&ranking=unranked&summary=mysummary")
    result.sort_results_by("documentid")
    assert_equal(exp_tensors.size, result.hitcount)
    for i in 0...exp_tensors.size do
      exp_value = exp_tensors[i]
      act_value = result.hit[i].field[field_name]
      puts "#{i}: '#{exp_value}' == '#{act_value}' ?"
      assert_tensor_field(exp_value, result, field_name, i)
    end
  end

  def assert_field_values(result, field_name, exp_values)
    result.sort_results_by("documentid")
    assert_equal(exp_values.size, result.hitcount)
    for i in 0...exp_values.size do
      exp_value = exp_values[i]
      act_value = result.hit[i].field[field_name]
      puts "#{i}: '#{exp_value}' == '#{act_value}' ?"
      assert_equal(exp_value, act_value)
    end
  end

  def teardown
    stop
  end

end
