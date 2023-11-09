# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Vespafeeder < IndexedSearchTest

  def setup
    set_owner("vekterli")
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "music.sd"))
    start
  end

  def test_error_behaviour
    node = vespa.nodeproxies.values.first

    # Would be nice to have each test in a separate function so we could see
    # all that was failing and not just first, but as it's so much overhead
    # to start stop test, keep all tests in one function for now
    node.copy(selfdir + "unknown_doctype.xml", "/tmp/")
    node.copy(selfdir + "music.xml", "/tmp/")
    node.copy(selfdir + "wrongfield.xml", "/tmp/")

    # Test that we fail decently when using unknown document type
    (exitcode, output) = node.execute("VESPA_LOG_TARGET='file:/dev/null' vespa-feeder /tmp/unknown_doctype.xml /tmp/music.xml", { :exitcode => true, :stderr => true })
    assert_equal(1, exitcode.to_i)
    assert(output.index("Must specify an existing document type") != nil)

    # Test that we fail decently when input file does not exist
    (exitcode, output) = node.execute("VESPA_LOG_TARGET='file:/dev/null' vespa-feeder nonexisting.xml 2>&1", { :exitcode => true, :stderr => true })
    assert_equal(1, exitcode.to_i)
    assert(output.index("Could not open file") != nil);

    # Test that we fail decently when having document XML with field that
    (exitcode, output) = node.execute("VESPA_LOG_TARGET='file:/dev/null' vespa-feeder /tmp/wrongfield.xml 2>&1", { :exitcode => true, :stderr => true })
    assert_equal(1, exitcode.to_i)
    assert(output.index("Field wrong not found") != nil);
  end

  def teardown
    node = vespa.nodeproxies.values.first
    node.execute("rm -f /tmp/unknown_doctype.xml")
    node.execute("rm -f /tmp/music.xml")
    node.execute("rm -f /tmp/wrongfield.xml")
    stop
  end

end
