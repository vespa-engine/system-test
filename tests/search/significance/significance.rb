require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class SignificanceTest < IndexedStreamingSearchTest

  def setup
    set_owner("MariusArhaug")
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

  def test_default_significance_searcher
    deploy_app(
      SearchApp.new.
        container(
          Container.new('default').
            search(
              Searching.new.
                significance(default_significance_model_component)
            ).
            docproc(DocumentProcessing.new)).
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
            docproc(DocumentProcessing.new)).
        sd(selfdir + 'app_one_significance/schemas/doc.sd').
        components_dir(selfdir + 'app_one_significance/models').
        indexing_cluster('default').indexing_chain('indexing'))
    start
    feed_and_wait_for_docs("doc", 2, :file => selfdir + "docs.json")
    verify_significance_for_and_query
  end

  def verify_default_significance_for_simple_query
    #result = search("?yql=select%20*%20from%20sources%20*%20where%20text%20contains%20%22hello%22&format=json&trace.level=9").xmldata
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