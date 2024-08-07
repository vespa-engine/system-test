# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'json'

class XGBoostServing < IndexedStreamingSearchTest

  def setup
    @valgrid = false
    set_owner("jobergum")
    set_description("Test XGBoost model representation in Vespa")
  end

  def compare(vespa_prediction,dataset)
    xgboost_prediction = @predictions[dataset]
    print("Comparing for #{dataset}")
    for i in (0...xgboost_prediction.length)
      assert_in_delta(xgboost_prediction[i], vespa_prediction[i],0.0001, message="Vespa prediction for data id #{i} does not match")
    end
  end

  def make_app
    SearchApp.new.sd(selfdir + 'app/schemas/x.sd')
  end

  def test_xgboost
    node_proxy = vespa.nodeproxies.values.first
    tmp_dir = dirs.tmpdir + "/training"
    node_proxy.execute("mkdir -p #{tmp_dir}/models")
    for file in ['train.py', 'feature-map-10.txt', 'feature-map-30.txt']
      node_proxy.copy(selfdir + file, tmp_dir)
    end
    node_proxy.execute("python3 #{tmp_dir}/train.py #{tmp_dir}/ #{tmp_dir}/models/ #{tmp_dir}/ #{tmp_dir}/predictions.json")
    @predictions = JSON.parse(node_proxy.readfile("#{tmp_dir}/predictions.json"))
    deploy_files = { selfdir + 'app/search/query-profiles/default.xml' => 'search/query-profiles/default.xml' }
    FileUtils.mkdir_p("#{tmp_dir}/models")
    models = node_proxy.execute("cd #{tmp_dir}/models && echo *").split
    for model in models
      model_file = tmp_dir + '/models/' + model
      File.write(model_file, node_proxy.readfile("#{tmp_dir}/models/" + model))
      deploy_files[model_file] = 'models/' + model
    end
    deploy_app(make_app, :files => deploy_files)
    start

    #Feed files generated from setup/train.py
    feed(:file => "#{tmp_dir}/diabetes-feed.json", :localfile => true)
    feed(:file => "#{tmp_dir}/breast_cancer-feed.json", :localfile => true)
    wait_for_hitcount("query=sddocname:x", 569 + 442, is_streaming ? 120 : 60)

    regression_diabetes = getVespaPrediction("diabetes", "regression-diabetes")
    compare(regression_diabetes, "regression_diabetes")

    regression_breast_cancer = getVespaPrediction("breast_cancer", "regression-breast_cancer")
    compare(regression_breast_cancer, "regression_breast_cancer")

    binary_breast_cancer = getVespaPrediction("breast_cancer", "binary-probability-breast_cancer")
    compare(binary_breast_cancer, "binary_breast_cancer")
  end

  def getVespaPrediction(dataset,rankProfile)
    result = search("/search/?query=dataset:#{dataset}&format=json&hits=1000&ranking=#{rankProfile}")
    tree = JSON.parse(result.xmldata)
    hits = tree["root"]["children"]
    predictions = {}
    hits.each do |hit|
      score = hit['relevance']
      id = hit['fields']['id']
      predictions[id] = score
    end
    predictions_array = []
    predictions.keys().sort().each do |id|
      predictions_array.push(predictions[id])
    end
    return predictions_array
  end

  def teardown
    stop
  end

end
