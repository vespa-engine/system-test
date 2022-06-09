# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'json'

class LightGBMEvaluationTest < IndexedSearchTest

  def setup
    @valgrid = false
    set_owner("lesters")
    set_description("Validate evaluation of LightGBM models - in model-evaluation and in ranking")
  end

  def teardown
    stop
  end

  def test_lightgbm_evaluation
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("lightgbm", 100, :file => selfdir + "feed.json")

    result = search("query=sddocname:lightgbm&hits=100&ranking=default")
    result.hit.each { |hit|
      expected = hit.field["expected"].to_f
      result_from_ranking = hit.field["relevancy"].to_f

      assert_equals(expected, result_from_ranking)
      assert_equals(expected, stateless_model_eval(hit, "lightgbm_classification"))
    }
  end

  def stateless_model_eval(hit, model)
    eval_url = "/model-evaluation/v1/#{model}/eval/?format.tensors=long&"
    if hit.field.has_key? "num_1"
      eval_url += "numerical_1=%s&" % hit.field["num_1"].to_f
    end
    if hit.field.has_key? "num_2"
      eval_url += "numerical_2=%s&" % hit.field["num_2"].to_f
    end
    if hit.field.has_key? "cat_1"
      eval_url += "categorical_1=%s&" % hit.field["cat_1"]
    end
    if hit.field.has_key? "cat_2"
      eval_url += "categorical_2=%s&" % hit.field["cat_2"]
    end
    eval_result = JSON.parse(vespa.container.values.first.http_get("localhost", 0, eval_url).body)
    return eval_result["cells"][0]["value"].to_f
  end

  def assert_equals(a, b)
    assert((a-b).abs < 0.00001)
  end


end

