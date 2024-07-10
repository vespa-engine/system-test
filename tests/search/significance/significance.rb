# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

    deploy_app(SearchApp.new.
      container(
        Container.new('default').
          search(Searching.new).
          docproc(DocumentProcessing.new).
          documentapi(ContainerDocumentApi.new)).
      sd(selfdir + 'app_one_significance/schemas/doc.sd').
      indexing_cluster('default').indexing_chain('indexing'))
    start

    vespa.adminserver.
      execute(
        "vespa-significance generate --in \"#{input_file}\" --out \"#{output_file}\" --field text --language en --doc-type en --zst-compression true",
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

    output = deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            search(
              Searching.new.
                significance(significance_generated_model_component)
            ).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new)).
        sd(selfdir + 'app_one_significance/schemas/doc.sd').
        components_dir(@models_dir).
        indexing_cluster('default').indexing_chain('indexing'))
    wait_for_application(vespa.container.values.first, output)
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_default_significance_for_simple_query
  end

  def test_default_significance_searcher
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            search(
              Searching.new.
                significance(default_significance_model_component)
            ).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new)).
        sd(selfdir + 'app_one_significance/schemas/doc.sd').
        components_dir(selfdir + 'app_one_significance/models').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_default_significance_for_simple_query
  end

  def test_significance_searcher_with_multiple_models
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            search(
              Searching.new.
                significance(significance_model_component_multiple_models)
            ).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new)).
        sd(selfdir + 'app_one_significance/schemas/doc.sd').
        components_dir(selfdir + 'app_one_significance/models').
        indexing_cluster('default').indexing_chain('indexing'))
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
