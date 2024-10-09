# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class SignificanceTest < IndexedStreamingSearchTest

  N = 1000000.0 # Corpus size for legacy significance

  def setup
    set_owner("MariusArhaug")
    @mytmpdir = dirs.tmpdir
    puts("Using temporary directory '#{@mytmpdir}'..")
  end

  def make_app(significance, models_dir)
    container = Container.new('default').
                  docproc(DocumentProcessing.new).
                  documentapi(ContainerDocumentApi.new)
    container.search(Searching.new.
                       significance(significance)) unless significance.nil?
    app = SearchApp.new.
            container(container).
            sd(selfdir + 'app_one_significance/schemas/doc.sd').
            indexing_cluster('default').indexing_chain('indexing')
    app.components_dir(models_dir) unless models_dir.nil?
    app
  end

  # Reimplementation of calculate_legacy_significance in C++
  # https://github.com/vespa-engine/vespa/blob/b6a2fcbbd80c82d683fc409ed7a0d61b8abc9dc8/searchlib/src/vespa/searchlib/features/utils.cpp#L108
  def calculate_legacy_significance(frequency, count)
    return 0.5 if count == 0
    frequency = [[1.0, frequency.to_f * N / count.to_f].max, N].min
    count = N
    logcount = Math.log(count.to_f)
    logfrequency = Math.log(frequency.to_f)
    # Using traditional formula for inverse document frequency, see
    # https://en.wikipedia.org/wiki/Tf%E2%80%93idf#Inverse_document_frequency
    idf = logcount - logfrequency
    # We normalize against document frequency 1 in corpus of N documents.
    normalized_idf = idf / logcount # normalized to range [0;1]
    renormalized_idf = 0.5 + 0.5 * normalized_idf # normalized to range [0.5;1]
    renormalized_idf
  end

  def generate_default_significance_model_from_vespa_dump_file
    input_file = selfdir + "app_one_significance/models/en.jsonl"
    output_file = @mytmpdir + "model.json.zst"
    @models_dir = @mytmpdir + "models"

    deploy_app(make_app(nil, nil))
    start

    vespa.adminserver.
      execute(
        "vespa-significance generate --in \"#{input_file}\" --out \"#{output_file}\" --field text --language en --zst-compression true",
        :exceptiononfailure => true)

    FileUtils.mkdir_p(@models_dir)
    vespa.nodeproxies.first[1].copy_remote_file_into_local_directory(output_file, @models_dir)

  end

  def default_significance_model_component
    Significance.new.
      model("components/docv1.json")
  end

  def significance_model_component_multiple_models
    Significance.new.
      model("components/docv1.json").
      model("components/docv2.json")
  end

  def significance_generated_model_component
    Significance.new.
      model("components/model.json.zst")
  end

  def test_default_significance_searcher_with_generated_significance_model
    generate_default_significance_model_from_vespa_dump_file

    output = deploy_app(make_app(significance_generated_model_component,
                                 @models_dir))
    wait_for_application(vespa.container.values.first, output)
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_default_significance_for_simple_query
  end

  def test_default_significance_searcher
    deploy_app(make_app(default_significance_model_component,
                        selfdir + 'app_one_significance/models'))
    start
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_default_significance_for_simple_query
  end

  def test_significance_searcher_with_multiple_models
    deploy_app(make_app(significance_model_component_multiple_models,
                        selfdir + 'app_one_significance/models'))
    start
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_significance_for_and_query
  end

  def verify_default_significance_for_simple_query
    result = search({'yql' => 'select * from sources * where text contains "hello"', 'format' => 'json'}).json
    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    # "hello" { frequency: 3, count: 12 }
    exp_significance = calculate_legacy_significance(3, 12)
    assert_approx(exp_significance, significance_value)
  end


  def verify_significance_for_and_query
    result = search({'yql' => 'select * from sources * where text contains "hello" and text contains "world"', 'format' => 'json'}).json
    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    # "hello" { frequency: 3, count: 16 }
    exp_significance = calculate_legacy_significance(3, 16)
    assert_approx(exp_significance, significance_value)

    result = search({'yql' => 'select * from sources * where text contains "hei" and text contains "verden"', 'format' => 'json'}).json

    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    # "hei" { frequency: 1, count: 16 }
    exp_significance = calculate_legacy_significance(1, 16)
    assert_approx(exp_significance, significance_value)
  end

  def teardown
    stop
  end
end
