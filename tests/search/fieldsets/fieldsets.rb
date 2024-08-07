# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class FieldSets < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
  end

  def test_fieldset_search
    deploy_app(SearchApp.new.sd(selfdir+"fieldsets.sd"))
    start
    feed_and_wait_for_docs("fieldsets", 4, :file => selfdir+"fieldsets.json")
    assert_hitcount("fs1:se", 4)
    assert_hitcount("fs1:%22test se 2%22", 1)
    assert_hitcount("fs1:sf", 4)
    assert_hitcount("fs1:30", 2)
    assert_hitcount("sb", 4)
    assert_hitcount("test'sb", 4)
    assert_hitcount("sb'test", 4) # Reverse matches since phrase-segmentation false: Linguistics tokenized
    assert_hitcount("sb-test", 4) # Reverse matches since phrase-segmentation false: Query parser tokenized                                                                                     
    assert_hitcount("%22test sb 2%22", 1)
    # searching in attributes as well
    assert_hitcount("fs1:onlyindoc", 3)
    assert_hitcount("fs4:%3C20", 3)
    # stemming
    # Stemming is not supported in streaming mode
    assert_hitcount("fs1:fishes", 1) unless is_streaming
    assert_hitcount("fs1:fish", 1)
    # Stemming is not supported in streaming mode
    assert_hitcount("sa:fishes", 1) unless is_streaming
    assert_hitcount("sa:fish", 1)
    # normalization
    assert_hitcount("fs1:pass%C3%A9", 1)
    assert_hitcount("fs1:passe", 1)
    assert_hitcount("se:pass%C3%A9", 1)
    assert_hitcount("se:passe", 1)
    # exact
    assert_hitcount("exact12:e 1%40%40", 3)
    assert_hitcount("exact34:G 3Arnold", 2)
    assert_hitcount("exact34:h3Arnold", 1)
    # ngram
    # ngram is not supported in streaming mode
    assert_hitcount("ngram:bc", 3) unless is_streaming
    # prefix
    assert_hitcount("pref:fo%2A", 1)
  end

  def teardown
    stop
  end

end

