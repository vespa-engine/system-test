# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'
require 'json'

class XGBoostMissingValues < IndexedStreamingSearchTest

  def setup
    @valgrid = false
    set_owner("lesters")
    set_description("Validate evaluation of XGBoost models with missing values - in model-evaluation and in ranking")
  end

  def teardown
    stop
  end

  def make_services_xml(app_dir)
    app = SearchApp.new
    container = Container.new('default').search(Searching.new)
    container.component("    <model-evaluation />\n")
    app.container(container)
    app.sd(app_dir + '/schemas/xgboost.sd')
    app.search_type(@params[:search_type])
    f = File.open("#{app_dir}/services.xml", 'w')
    f.write(app.services_xml)
    f.close
  end

  def test_xgboost_missing_values
    tmp_dir = dirs.tmpdir + '/tmp'
    FileUtils.mkdir_p("#{tmp_dir}")
    FileUtils.cp_r(selfdir + "app", "#{tmp_dir}/app", verbose: true)
    make_services_xml("#{tmp_dir}/app")
    deploy("#{tmp_dir}/app")
    start
    feed_and_wait_for_docs("xgboost", 9, :file => selfdir + "feed.json")

    result = search("query=sddocname:xgboost&hits=9&ranking=default")
    result.hit.each { |hit|
      expected = hit.field["expected"].to_f
      result_from_ranking = hit.field["relevancy"].to_f

      assert_equals(expected, result_from_ranking)
      assert_equals(expected, stateless_model_eval(hit, "xgboost_if_inversion"))
    }
  end

  def stateless_model_eval(hit, model)
    eval_url = "/model-evaluation/v1/#{model}/eval/?format.tensors=long&"
    if hit.field.has_key? "field1"
      eval_url += "f1=%s&" % hit.field["field1"].to_f
    end
    if hit.field.has_key? "field2"
      eval_url += "f2=%s" % hit.field["field2"].to_f
    end
    eval_result = JSON.parse(vespa.container.values.first.http_get("localhost", 0, eval_url).body)
    return eval_result["cells"][0]["value"].to_f
  end

  def assert_equals(a, b)
    assert((a-b).abs < 0.00001)
  end


end

