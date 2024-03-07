# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class LuceneLinguistics < IndexedOnlySearchTest

  def setup
    set_owner("hmusum")
    set_description("Tests that we can specify using the lucene linguistcs implementation")
  end

  def test_simple_linguistics
    deploy_app(SearchApp.new.
                 container(
                   Container.new('default').
                     component(lucene_linguistics_component).
                     search(Searching.new).
                     docproc(DocumentProcessing.new)).
                 sd(selfdir + 'lucene.sd'))
    start
    feed_and_wait_for_docs("lucene", 1, :file => selfdir + "document.json")

    assert_hitcount("query=dog", 1)
  end

  def lucene_linguistics_component
      Component.new('lucene-linguistics').
        klass('com.yahoo.language.lucene.LuceneLinguistics').
        bundle('lucene-linguistics').
        config(ConfigOverride.new('com.yahoo.language.lucene.lucene-analysis'))
  end

  def teardown
    stop
  end

end
