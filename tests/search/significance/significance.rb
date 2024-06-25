require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'
require 'indexed_only_search_test'

class SignificanceTest < IndexedStreamingSearchTest

  def setup
    set_owner("MariusArhaug")
    @mytmpdir = dirs.tmpdir
    puts("Using temporary directory '#{@mytmpdir}'..")
  end

  def generate_default_significance_model_from_vespa_dump_file
    input_file = selfdir + "app_one_significance/models/en.jsonl"
    output_file = @mytmpdir + "model.json"
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
        "vespa-significance generate --in \"#{input_file}\" --out \"#{output_file}\" --field text --language en --doc-type en --zst-compression false",
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
      model("components/model.json")
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
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22&format=json").json
    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    assert(significance_value == 1.3121863889661687, "Expected significance to be 1.3121863889661687, but was #{significance_value}")
  end


  def verify_significance_for_and_query
    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22%20and%20text%20contains%20%22world%22&format=json").json
    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    assert(significance_value == 1.580450375560848, "Expected significance to be 1.580450375560848, but was #{significance_value}")

    result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hei%22%20and%20text%20contains%20%22verden%22&format=json").json

    significance_value = result["root"]["children"][0]["fields"]["summaryfeatures"]["term(0).significance"]
    assert(significance_value == 2.4277482359480516, "Expected significance to be 2.4277482359480516, but was #{significance_value}")
  end

  def teardown
    stop
  end
end
