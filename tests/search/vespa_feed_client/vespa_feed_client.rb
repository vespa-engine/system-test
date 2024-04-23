# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class VespaFeedClient < IndexedStreamingSearchTest

  def setup
    set_owner("vekterli")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "music.sd"))
    start
  end

  def test_error_behaviour
    node = vespa.nodeproxies.values.first

    # Feed with valid docs
    (exitcode, output) = feed(:file => selfdir + 'music.json', :client => :vespa_feed_client, :exitcode => true, :stderr => true)
    assert_equal(0, exitcode.to_i)

    # Test that we fail decently when using unknown document type
    (exitcode, output) = feed(:file => selfdir + 'unknown_doctype.json', :client => :vespa_feed_client, :exitcode => true, :stderr => true)
    assert_equal(0, exitcode.to_i) # Some docs fed successfully, so expect 0
    assert(output.index("Document type nonexistingtype does not exist"))

    # Test that we fail decently when having a document with a field that does not exist
    (exitcode, output) = feed(:file => selfdir + 'wrongfield.json', :client => :vespa_feed_client, :exitcode => true, :stderr => true)
    assert_equal(0, exitcode.to_i) # Some docs fed successfully, so expect 0
    assert(output.index("No field 'wrong' in the structure of type 'music'"))
  end

  def teardown
    stop
  end

end
