# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class LuceneLinguistics < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Tests with the Lucene linguistcs implementation")
  end

  def test_simple_linguistics
    set_expected_logged(/Lucene cannot optimize algorithms or calculate object sizes for JVMs that are not based on Hotspot or a compatible implementation/)
    deploy_app(SearchApp.new.
                 container(
                   Container.new('default').
                     component(lucene_linguistics_component).
                     search(Searching.new).
                     docproc(DocumentProcessing.new).
                     documentapi(ContainerDocumentApi.new)).
                 sd(selfdir + 'lucene.sd'))
    start
    feed_and_wait_for_docs("lucene", 1, :file => selfdir + "document.json")

    assert_hitcount("query=dog", 1)
  end

  def lucene_linguistics_component
      Component.new('lucene-linguistics').
        klass('com.yahoo.language.lucene.LuceneLinguistics').
        bundle('lucene-linguistics').
        config(ConfigOverride.new('com.yahoo.language.lucene.lucene-analysis').
               add(MapConfig.new('analysis').
                   add('profile=specialTokens',
                       ConfigValue.new().
                         add(ConfigValue.new('tokenizer').add('name', 'pattern')
                                                         .add(MapConfig.new('conf').add('pattern', ""))).
                         add(ArrayConfig.new('tokenFilters').add(0, 'lowercase')))))
  end

end
