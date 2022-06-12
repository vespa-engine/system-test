# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

  def tensorflow_test_model_evaluation

    # ---- xgboost
    result = query("/models/?model=xgboost_2_2&function=xgboost_2_2")
    assert_equal("{\"cells\":[{\"address\":{},\"value\":2.496898}]}", result.body)

    # ---- mnist_softmax (onnx)
    #    - no argument
    result = query("/models/?model=mnist_softmax&function=y" +
                   "&argumentName=Placeholder_0" +
                   "&argumentValue=" + URI::encode(generateAllZeroArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-1.6372650861740112E-6}]}", result.body)
    #    - with argument
    result = query("/models/?model=mnist_softmax&function=y" +
                   "&argumentName=Placeholder_0" +
                   "&argumentValue=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":2.4199485778808594E-5}]}", result.body)

    # ---- mnist_softmax_saved (tensorflow)
    #    - no argument
    result = query("/models/?model=mnist_softmax_saved&function=serving_default.y" +
                   "&argumentName=Placeholder" +
                   "&argumentValue=" + URI::encode(generateAllZeroArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-1.6372650861740112E-6}]}", result.body)
    #    - with argument
    result = query("/models/?model=mnist_softmax_saved&function=serving_default.y" +
                   "&argumentName=Placeholder" +
                   "&argumentValue=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":9.119510650634766E-6}]}", result.body)

    # ---- mnist_saved (tensorflow, with generated macros)
    #    - no argument
    result = query("/models/?model=mnist_saved&function=serving_default.y" +
                   "&argumentName=input" +
                   "&argumentValue=" + URI::encode(generateAllZeroArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-0.7146291686221957}]}", result.body)
    #    - with argument
    result = query("/models/?model=mnist_saved&function=serving_default" +
                   "&argumentName=input" +
                   "&argumentValue=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":6.658839702606201}]}", result.body)

  end

  def tensorflow_test_model_evaluation_rest_api

    # list available models
    result = query("/model-evaluation/v1/")
    assert(result.body.include? "\"xgboost_2_2\"")
    assert(result.body.include? "\"mnist_softmax\"")
    assert(result.body.include? "\"mnist_softmax_saved\"")
    assert(result.body.include? "\"mnist_saved\"")

    # TODO: add type test when it is available

    # evaluate xboost_2_2 model (only has one function, thus optional)
    result = query("/model-evaluation/v1/xgboost_2_2/eval")
    assert_equal("{\"cells\":[{\"address\":{},\"value\":2.496898}]}", result.body)

    # evaluate mnist_softmax model (only has one function, thus optional)
    result = query("/model-evaluation/v1/mnist_softmax/eval" +
                   "?Placeholder_0=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":0.8232707381248474},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-9.757275581359863},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":6.982227802276611},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":6.577242851257324},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-6.682279109954834},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":6.788743495941162},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":0.4913627505302429},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-3.539299726486206},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":1.3475146293640137},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-3.0314836502075195}]}", result.body)

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal(200, result.code.to_i)

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/serving_default.y/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":-0.9851940870285034},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-3.3600471019744873},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":10.35411262512207},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":12.595134735107422},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-7.51699686050415},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":3.359957218170166},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":-8.216789245605469},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-4.859930515289307},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":5.97797155380249},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-0.6893786191940308}]}", result.body)

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/serving_default/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":-0.9851940870285034},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-3.3600471019744873},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":10.35411262512207},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":12.595134735107422},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-7.51699686050415},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":3.359957218170166},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":-8.216789245605469},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-4.859930515289307},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":5.97797155380249},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-0.6893786191940308}]}", result.body)

    # ---- vespa (only tested with this API since we require 2 arguments which the ad hoc (models) API doesn't support
    #    - function using small constant
    result = query("/model-evaluation/v1/vespa_example/foo1/eval" +
                   "?input1=" + URI::encode("{{name:a, x:0}: 1, {name:a, x:1}: 2, {name:a, x:2}: 3}") +
                   "&input2=" + URI::encode("{{x:0}:3, {x:1}:6, {x:2}:9}"))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":202.5}]}", result.body)
    #    - function using large constant
    result = query("/model-evaluation/v1/vespa_example/foo2/eval" +
                   "?input1=" + URI::encode("{{name:a, x:0}: 1, {name:a, x:1}: 2, {name:a, x:2}: 3}") +
                   "&input2=" + URI::encode("{{x:0}:3, {x:1}:6, {x:2}:9}"))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":202.5}]}", result.body)
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
