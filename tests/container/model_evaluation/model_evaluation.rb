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

  def test_model_evaluation

    # ---- xgboost
    result = query("/models/?model=xgboost_2_2&function=xgboost_2_2")
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-8.17695}]}", result.body)

    # ---- mnist_softmax (onnx)
    #    - no argument
    result = query("/models/?model=mnist_softmax&function=default.add" +
                   "&argumentName=Placeholder" +
                   "&argumentValue=" + URI::encode(generateAllZeroArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-1.6372650861740112E-6}]}", result.body)
    #    - with argument
    result = query("/models/?model=mnist_softmax&function=default.add" +
                   "&argumentName=Placeholder" +
                   "&argumentValue=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":8.949087578535853E-6}]}", result.body)

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
    assert_equal("{\"cells\":[{\"address\":{},\"value\":8.949087578535853E-6}]}", result.body)

    # ---- mnist_saved (tensorflow, with generated macros)
    #    - no argument
    result = query("/models/?model=mnist_saved&function=serving_default.y" +
                   "&argumentName=input" +
                   "&argumentValue=" + URI::encode(generateAllZeroArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-0.714629192618967}]}", result.body)
    #    - with argument
    result = query("/models/?model=mnist_saved&function=serving_default" +
                   "&argumentName=input" +
                   "&argumentValue=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{},\"value\":6.65883909709195}]}", result.body)
  end

  def test_model_evaluation_rest_api

    # list available models
    result = query("/model-evaluation/v1/")
    assert(result.body.include? "\"xgboost_2_2\"")
    assert(result.body.include? "\"mnist_softmax\"")
    assert(result.body.include? "\"mnist_softmax_saved\"")
    assert(result.body.include? "\"mnist_saved\"")

    # TODO: add type test when it is available

    # evaluate xboost_2_2 model (only has one function, thus optional)
    result = query("/model-evaluation/v1/xgboost_2_2/eval")
    assert_equal("{\"cells\":[{\"address\":{},\"value\":-8.17695}]}", result.body)

    # evaluate mnist_softmax model (only has one function, thus optional)
    result = query("/model-evaluation/v1/mnist_softmax/eval" +
                   "?Placeholder=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":0.8232705493311443},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-9.757276956504713},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":6.9822281524124215},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":6.5772413370875205},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-6.682286614129955},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":6.788742593462982},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":0.49136128040612614},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-3.539295991298334},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":1.3475151895535347},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-3.031490591233149}]}", result.body)

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal(404, result.code.to_i)  # model has more than one function

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/serving_default.y/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":-0.9851942175674907},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-3.3600470848109443},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":10.354113129610678},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":12.59513385100048},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-7.516996382917508},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":3.359956718406166},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":-8.21678924075764},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-4.859930426566943},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":5.977971539591458},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-0.6893787888963082}]}", result.body)

    # evaluate mnist_saved model
    result = query("/model-evaluation/v1/mnist_saved/serving_default/eval" +
                   "?input=" + URI::encode(generateArgument()))
    assert_equal("{\"cells\":[{\"address\":{\"d0\":\"0\",\"d1\":\"0\"},\"value\":-0.9851942175674907},{\"address\":{\"d0\":\"0\",\"d1\":\"1\"},\"value\":-3.3600470848109443},{\"address\":{\"d0\":\"0\",\"d1\":\"2\"},\"value\":10.354113129610678},{\"address\":{\"d0\":\"0\",\"d1\":\"3\"},\"value\":12.59513385100048},{\"address\":{\"d0\":\"0\",\"d1\":\"4\"},\"value\":-7.516996382917508},{\"address\":{\"d0\":\"0\",\"d1\":\"5\"},\"value\":3.359956718406166},{\"address\":{\"d0\":\"0\",\"d1\":\"6\"},\"value\":-8.21678924075764},{\"address\":{\"d0\":\"0\",\"d1\":\"7\"},\"value\":-4.859930426566943},{\"address\":{\"d0\":\"0\",\"d1\":\"8\"},\"value\":5.977971539591458},{\"address\":{\"d0\":\"0\",\"d1\":\"9\"},\"value\":-0.6893787888963082}]}", result.body)
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
