# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class NfkcNormalization < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Check NFKC normalization is actually performed.")
  end

  def deploy_start_and_feed
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    start
    feed_and_wait_for_docs("simple", 6, :file => selfdir+"simple.6.json", :timeout => 240)
  end

  def self.final_test_methods
    ['test_nfkc']
  end

  def test_nfkc
    @params = { :search_type => 'ELASTIC' }
    deploy_start_and_feed
    # check symbol to ascii
    assert_hitcount("/search/?query=xii", 1)

    # now for searching using the original forms:
    # Roman numeral twelve
    # assert_hitcount("/search/?query=%E2%85%AB", 1)
    assert_hitcount("/search/?query=select+%2A+from+sources+%2A+where+default+contains+%22%E2%85%AB%22%3B&type=yql", 1)
  end

  def test_doublewidth
    deploy_start_and_feed
    # check a fullwidth, uppercased word which has been changed in stemming
    assert_hitcount("/search/?query=raised", 1)
    # check a fullwidth, lowercased word which has been changed in stemming
    assert_hitcount("/search/?query=lower", 1)
    # check a fullwidth, uppercased word which has not been changed in stemming
    assert_hitcount("/search/?query=foo", 1)
    # check a fullwidth, lowercased word which has not been changed in stemming
    assert_hitcount("/search/?query=bar", 1)

    # now for searching using the original forms:
    # "RAISED" in fullwidth
    assert_hitcount("/search/?query=%EF%BC%B2%EF%BC%A1%EF%BC%A9%EF%BC%B3%EF%BC%A5%EF%BC%A4", 1)
    # "lower" in fullwidth
    assert_hitcount("/search/?query=%EF%BD%8C%EF%BD%8F%EF%BD%97%EF%BD%85%EF%BD%92", 1)
    # "FOO" in fullwidth
    assert_hitcount("/search/?query=%EF%BC%A6%EF%BC%AF%EF%BC%AF", 1)
    # "bar" in fullwidth
    assert_hitcount("/search/?query=%EF%BD%82%EF%BD%81%EF%BD%92", 1)
  end

  def test_doublewidth_numeric
    deploy_start_and_feed
    # check a fullwidth, lowercased numeric which has not been changed in stemming
    assert_hitcount("/search/?query=168", 1)
    # "168" in fullwidth
    assert_hitcount("/search/?query=%EF%BC%91%EF%BC%96%EF%BC%98", 1)
  end

  def teardown
    stop
  end

end
