# Copyright Vespa.ai. All rights reserved.

require 'vds/visitor/visitor'

class VisitorPart2Test < VisitorTest

  def test_visit_bucket_bogus_selection
    doInserts()

    visitBogusSelection()
  end

  def test_visit_all_distributors_down
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "numResults before insert is " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    assert_equal(4, numResults)

    vespa.storage["storage"].distributor["0"].stop
    vespa.storage["storage"].distributor["1"].stop

    vespa.storage["storage"].wait_until_cluster_down

    # Try to run a visitor when the distributor is down => should fail
    visitClusterDown()
  end

  def test_visit_1_of_2_storagenodes_down
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "0 numResults = " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    puts "1 numResults = " + numResults.to_s
    assert_equal(4, numResults)

    vespa.stop_content_node("storage", "1")

    # Run a visitor again when storage node has stopped
    numResults = checkVisiting([], 0, 0, "")
    puts "2 numResults = " + numResults.to_s
    assert_equal(4, numResults)
  end

  def test_visit_1_of_2_distributors_down
    # Run a visitor before inserting to make sure storage is empty
    numResults = checkVisiting([], 0, 0, "")
    puts "0 numResults = " + numResults.to_s
    assert_equal(0, numResults)

    doInserts()

    # Run a visitor when all is ok
    numResults = checkVisiting([], 0, 0, "")
    puts "1 numResults = " + numResults.to_s
    assert_equal(4, numResults)

    vespa.storage["storage"].distributor["1"].stop

    vespa.storage["storage"].wait_until_ready(30, ["1"])

    # Run a visitor again when distributor has stopped
    numResults = checkVisiting([], 0, 0, "")
    puts "2 numResults = " + numResults.to_s
    assert_equal(4, numResults)
  end

  def test_visit_removes
    doInserts()

    result = visit(0, 0, "", [])
    assert_equal(4, result.length)

    result = visit(0, 0, "", [], true)
    assert_equal(5, result.length)

    removeUser5678()

    result = visit(0, 0, "", [])
    assert_equal(2, result.length)

    result = visit(0, 0, "", [], true)
    assert_equal(5, result.length)
  end

end
