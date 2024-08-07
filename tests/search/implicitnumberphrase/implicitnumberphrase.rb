# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ImplicitNumberPhrase < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
  end

  def test_implicitnumberphrase
    feed_and_wait_for_docs("test", 3, :file => selfdir+"docs.json")
    assert_hitcount("query=test", 3)
    assert_hitcount("query=body:test", 3)

    assert_hitcount("query=5", 1)
    assert_hitcount("query=2.2", 1)
    assert_hitcount("query=3.3", 1)

    assert_hitcount("query=body:5", 1)
    assert_hitcount("query=body:2.2", 1)
    assert_hitcount("query=body:3.3", 1)

    # these should work, becomes ANDNOT
    assert_hitcount("query=test+-5&type=any", 2)
    assert_hitcount("query=test+-2.2&type=any", 2)
    assert_hitcount("query=test+-3.3&type=any", 2)

    assert_hitcount("query=test+-body:5&type=any", 2)
    assert_hitcount("query=test+-body:2.2&type=any", 2)
    assert_hitcount("query=test+-body:3.3&type=any", 2)

    # these may work for the wrong reason, becomes OR
    assert_hitcount("query=test+body:-5&type=any", 3)
    assert_hitcount("query=test+body:-2.2&type=any", 3)
    assert_hitcount("query=test+body:-3.3&type=any", 3)

  # pri 1: should work, triggers phrase
    assert_hitcount("query=body:\"2.2\"", 1)
    assert_hitcount("query=body:\"3.3\"", 1)

  # pri 2: used to work (searching for negative numbers in text)
    assert_hitcount("query=body:-5", 1)
    assert_hitcount("query=body:-2.2", 1)
    assert_hitcount("query=body:-3.3", 1)
    assert_hitcount("query=test+-body:-5&type=any", 2)
    assert_hitcount("query=test+-body:-2.2&type=any", 2)
    assert_hitcount("query=test+-body:-3.3&type=any", 2)
    # triggers phrase:
    assert_hitcount("query=\"-5\"", 1)
    assert_hitcount("query=\"-2.2\"", 1)
    assert_hitcount("query=\"-3.3\"", 1)

  # pri 3: used to work (searching for numbers as phrase):
    assert_hitcount("query=\"2+2\"", 1)
    assert_hitcount("query=\"3+3\"", 1)
    assert_hitcount("query=body:\"2+2\"", 1)
    assert_hitcount("query=body:\"3+3\"", 1)
  end

  def teardown
    stop
  end

end
