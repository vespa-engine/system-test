# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'json'

class XGBoostServing < IndexedStreamingSearchTest

  def setup
    @valgrid = false
    set_owner("musum")
    set_description("Test XGBoost model representation in Vespa")
  end

  def compare(vespa_prediction,dataset)
    xgboost_prediction = @predictions[dataset]
    puts "Comparing for #{dataset}"
    for i in (0...xgboost_prediction.length)
      assert_in_delta(xgboost_prediction[i], vespa_prediction[i],0.0001, message="Vespa prediction for data id #{i} does not match")
    end
  end

  def make_app
    SearchApp.new.sd(selfdir + 'app/schemas/x.sd')
  end

  # Tests extracting model (from xgboost 2.x or 3.x)
  def test_xgboost_extract_model
    here = dirs.tmpdir + '/here'
    feature_dir = selfdir
    models_dir = here + '/models'
    feeds_dir = here + '/feeds'
    predictions_file = here + '/predictions.json'
    FileUtils.mkdir_p(here)
    FileUtils.mkdir_p(models_dir)
    FileUtils.mkdir_p(feeds_dir)
    success = system("python3 #{selfdir}train.py #{feature_dir} #{models_dir}/ #{feeds_dir}/ #{predictions_file}")
    assert(success)
    deploy_files = { selfdir + 'app/search/query-profiles/default.xml' => 'search/query-profiles/default.xml' }
    for model in Dir.children(models_dir)
      model_file = "#{models_dir}/#{model}"
      deploy_files[model_file] = 'models/' + model
    end
    @predictions = JSON.parse(File.read(predictions_file))
    # extra base_score for binary:logistic
    prog = (selfdir + 'get_base_score.py')
    puts "Running #{prog}"
    system(prog)
    base_score=`#{prog} 2>/dev/null || echo 0.5`
    puts "Got base_score #{base_score}"
    if base_score && base_score.to_f > 0.0 && base_score.to_f < 1.0
      pp="m{base_score:} and s,0[.]5,#{base_score.to_f},"
      doit="perl -pe '#{pp}' < #{selfdir}app/schemas/x.sd > #{here}/x.sd"
      puts "Running #{doit}"
      success = system(doit)
      assert(success)
      puts "Using final schema: >>>\n#{File.read(here + '/x.sd')}\n<<<"
    else
      FileUtils.cp("#{selfdir}app/schemas/x.sd", "#{here}/x.sd")
    end
    deploy_app(SearchApp.new.sd("#{here}/x.sd"), :files => deploy_files)
    start

    #Feed files generated from setup/train.py
    feed(:file => "#{feeds_dir}/diabetes-feed.json")
    feed(:file => "#{feeds_dir}/breast_cancer-feed.json")
    wait_for_hitcount("query=sddocname:x", 569 + 442, is_streaming ? 120 : 60)

    regression_diabetes = getVespaPrediction("diabetes", "regression-diabetes")
    compare(regression_diabetes, "regression_diabetes")

    regression_breast_cancer = getVespaPrediction("breast_cancer", "regression-breast_cancer")
    compare(regression_breast_cancer, "regression_breast_cancer")

    binary_breast_cancer = getVespaPrediction("breast_cancer", "binary-probability-breast_cancer")
    compare(binary_breast_cancer, "binary_breast_cancer")
  end

  # uses old model exported from python 3.6
  def test_xgboost
    @predictions = JSON.parse(File.read(selfdir + "predictions.json"))
    deploy_files = {}
    [ "search/query-profiles/default.xml",
      "models/binary_breast_cancer.json",
      "models/regression_breast_cancer.json",
      "models/regression_diabetes.json",
    ].each {|f| deploy_files[selfdir + "app/#{f}"] = f }
    deploy_app(make_app, :files => deploy_files)
    start

    #Feed files generated from setup/train.py
    feed(:file => selfdir + "diabetes-feed.json")
    feed(:file => selfdir + "breast_cancer-feed.json")
    wait_for_hitcount("query=sddocname:x", 569 + 442, is_streaming ? 120 : 60)

    regression_diabetes = getVespaPrediction("diabetes", "regression-diabetes")
    compare(regression_diabetes, "regression_diabetes")

    regression_breast_cancer = getVespaPrediction("breast_cancer", "regression-breast_cancer")
    compare(regression_breast_cancer, "regression_breast_cancer")

    binary_breast_cancer = getVespaPrediction("breast_cancer", "binary-probability-breast_cancer")
    compare(binary_breast_cancer, "binary_breast_cancer")
  end

  def getVespaPrediction(dataset, rankProfile)
    puts "Getting #{rankProfile}"
    result = search("/search/?query=dataset:#{dataset}&format=json&hits=1000&ranking=#{rankProfile}")
    tree = JSON.parse(result.xmldata)
    hits = tree["root"]["children"]
    predictions = {}
    hits.each do |hit|
      score = hit['relevance']
      id = hit['fields']['id']
      predictions[id] = score
      if id == 0
        puts("Hit 0: #{hit}")
      end
    end
    predictions_array = []
    predictions.keys().sort().each do |id|
      predictions_array.push(predictions[id])
    end
    return predictions_array
  end


end
