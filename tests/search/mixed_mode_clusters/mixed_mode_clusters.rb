# Copyright Vespa.ai. All rights reserved.
require 'search_test'
require 'set'

class MixedModeClustersTest < SearchTest

  def setup
    set_owner('arnej')
  end

  def test_mixed_mode_clusters
    set_description("Test multiple content clusters with mixed mode documents")
    # Explicit use OpenNlpLinguistics to get the same results between public and internal system test runs.
    deploy_app(SearchApp.new.sd(selfdir + "a1indexed.sd", :mode => "index")
                            .sd(selfdir + "a1streaming.sd", :mode => "streaming")
                            .sd(selfdir + "a1storeonly.sd", :mode => "store-only")
                 .container(Container.new('container')
                              .search(Searching.new)
                              .documentapi(ContainerDocumentApi.new)
                              .component(Component.new('com.yahoo.language.opennlp.OpenNlpLinguistics'))
                              .config(ConfigOverride.new('ai.vespa.opennlp.open-nlp')
                                        .add('snowballStemmingForEnglish', 'true'))))
    start
    feed(:file => selfdir + "docs.json")
    check_q('true', 'search.a1indexed', 4)
    check_q('true', 'search.a1streaming', 4)
    check_q('true', 'search.a1store', 0)
    check_q('true', '*', 8)

    check_q('text contains "cars"', 'search.a1indexed', 1)
    check_q('text contains "cars"', 'search.a1storeonly', 0)
    check_q('{"stem":false} text contains "cars"', 'search.a1streaming', 1)
    # "cars" will stem to "car" which does not match in streaming, so these fail:
    # check_q('text contains "cars"', 'search.a1streaming', 1)
    # check_q('text contains "cars"', 'search', 2)
    # check_q('text contains "cars"', '*', 2)
    # so we get 1 less hit for all these:
    check_q('text contains "cars"', 'search.a1streaming', 0)
    check_q('text contains "cars"', 'search', 1)
    check_q('text contains "cars"', '*', 1)
  end

  def check_q(where, source, exp_hits)
    query = "yql=select * from sources #{source} where #{where}&streaming.selection=true&trace.level=1"
    result = search(query)
    if result.hitcount != exp_hits
      puts "BAD: query = #{query}"
      puts "Result = #{result.json}"
    end
    assert_hitcount(query, exp_hits)
  end

  def teardown
    stop
  end

end
