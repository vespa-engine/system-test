# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'uri'

class ModelEvaluation < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Test Java ML models evaluation.")

    add_bundle_dir(selfdir, "my_bundle")
    deploy(selfdir + "app")
    start
  end

  def test_model_evaluation

    # ---- xgboost
    result = query("/models/?model=xgboost_2_2&function=xgboost_2_2")
    assert_equal('{"type":"tensor()","cells":[{"address":{},"value":2.496898}]}', result.body)

    # ---- mnist_softmax (onnx)
    #    - no argument
    result = query("/models/?model=mnist_softmax&function=y" +
                   "&argumentName=Placeholder_0" +
                   "&argumentValue=" + CGI::escape(generateAllZeroArgument()))
    assert_equal('{"type":"tensor()","cells":[{"address":{},"value":-1.6372650861740112E-6}]}', result.body)
    #    - with argument
    result = query("/models/?model=mnist_softmax&function=y" +
                   "&argumentName=Placeholder_0" +
                   "&argumentValue=" + CGI::escape(generateArgument()))
    assert_equal('{"type":"tensor()","cells":[{"address":{},"value":2.4199485778808594E-5}]}', result.body)
  end

  def test_model_evaluation_rest_api

    # list available models
    result = query("/model-evaluation/v1/")
    puts "model list: #{result.body}"
    assert(result.body.include? "\"xgboost_2_2\"")
    assert(result.body.include? "\"mnist_softmax\"")

    # TODO: add type test when it is available

    # evaluate xboost_2_2 model (only has one function, thus optional)
    result = query("/model-evaluation/v1/xgboost_2_2/eval")
    assert_equal('{"type":"tensor()","values":[2.496898]}', result.body)

    # evaluate mnist_softmax model (only has one function, thus optional)
    result = query("/model-evaluation/v1/mnist_softmax/eval" +
                   "?Placeholder_0=" + CGI::escape(generateArgument()))
    assert_equal(
      '{"type":"tensor<float>(d0[1],d1[10])","values":[[0.8232707381248474,-9.757275581359863,6.982227802276611,6.577242851257324,-6.682279109954834,6.788743495941162,0.4913627505302429,-3.539299726486206,1.3475146293640137,-3.0314836502075195]]}',
      result.body)

    # ---- vespa (only tested with this API since we require 2 arguments which the ad hoc (models) API doesn't support
    #    - function using small constant
    result = query("/model-evaluation/v1/vespa_example/foo1/eval" +
                   "?input1=" + CGI::escape("{{name:a, x:0}: 1, {name:a, x:1}: 2, {name:a, x:2}: 3}") +
                   "&input2=" + CGI::escape("{{x:0}:3, {x:1}:6, {x:2}:9}"))
    assert_equal('{"type":"tensor()","values":[202.5]}', result.body)
    #    - function using large constant
    result = query("/model-evaluation/v1/vespa_example/foo2/eval" +
                   "?input1=" + CGI::escape("{{name:a, x:0}: 1, {name:a, x:1}: 2, {name:a, x:2}: 3}") +
                   "&input2=" + CGI::escape("{{x:0}:3, {x:1}:6, {x:2}:9}"))
    assert_equal('{"type":"tensor()","values":[202.5]}', result.body)
  end

  def query(query_string)
    vespa.container.values.first.http_get("localhost", 0, query_string)
  end

  def generateAllZeroArgument
    d0Size = 1
    d1Size = 784
    s = "{"
    for d0 in 0..(d0Size-1)
        for d1 in 0..(d1Size-1)
          if s.length > 1
              s.concat(",")
          end
          s.concat("{").concat("d0:").concat(d0.to_s).concat(",d1:").concat(d1.to_s).concat("}:").concat(0.to_s)
        end
    end
    s.concat("}");
    return s
  end

  def generateArgument
    d0Size = 1
    d1Size = 784
    s = "{"
    for d0 in 0..(d0Size-1)
        for d1 in 0..(d1Size-1)
          if s.length > 1
              s.concat(",")
          end
          s.concat("{").concat("d0:").concat(d0.to_s).concat(",d1:").concat(d1.to_s).concat("}:").concat((d1.to_f/d1Size.to_f).to_s)
        end
    end
    s.concat("}");
    return s
  end

  def teardown
    stop
  end

end
