# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#
# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'tempfile'
require 'test/unit'
require 'test_base'
require 'test/mocks/mock_vespa_model'
require 'test/unit_test'

class TestbaseTest < Test::Unit::TestCase
  def setup
    @vespamodel = MockVespaModel.new
    @qrserver = @vespamodel.qrserver["0"]
    @searchtest = UnitTest.new(@vespamodel)

  end

  def tst_assert_hitcount
    @searchtest.assert_hitcount("foobar", 1, 0)
    resultset = @qrserver.get_resultset()
    @searchtest.assert_hitcount(resultset, 1, 0)
    failed = 0
    begin
      @searchtest.assert_hitcount("foobar", 10, 0)
    rescue AssertionFailedError
      failed = 1
    end
    assert_equal(failed, 1)
    failed = 0
    begin
      @searchtest.assert_hitcount(resultset, 10, 0)
      fail("Should have thrown exception")
    rescue AssertionFailedError
      failed = 1
    end
    assert_equal(1, failed)
  end

  def tst_wait_hitcount
    @qrserver.set_delay(5)
    @searchtest.wait_for_hitcount("foobar", 10, 10, 0)

    @qrserver.set_delay(10)
    failed = false
    begin
      @searchtest.wait_for_hitcount("foobar", 10, 5, 0)
    rescue AssertionFailedError => e
      puts e.class
      failed = true
    end
    assert(failed, "Test didn't fail when it should have")
  end

  def test_search
    @qrserver.return_query = true
    resultset = @searchtest.search("?query=foobar")
    assert_equal("/search/?query=foobar&timeout=10", resultset.query)

    resultset = @searchtest.search("/?query=foobar")
    assert_equal("/search/?query=foobar&timeout=10", resultset.query)

    resultset = @searchtest.search("query=foobar")
    assert_equal("/search/?query=foobar&timeout=10", resultset.query)

    resultset = @searchtest.search("foobar")
    assert_equal("/search/?query=foobar&timeout=10", resultset.query)

    resultset = @searchtest.search("/search/?query=foobar")
    assert_equal("/search/?query=foobar&timeout=10", resultset.query)

    resultset = @searchtest.search("/Example/0/foo")
    assert_equal("/Example/0/foo&timeout=10", resultset.query)
  end

  def test_save_result
    tf = Tempfile.new("resfile")
    @searchtest.save_result("foobar", tf.path)
    assert(tf.size > 0)
  end

  def test_assert_httpresponse
    @searchtest.assert_httpresponse("foobar", {"header" => "test"}, 200, {"testheader" => "unittest"})
  end

  def test_assert_result
    tf = Tempfile.new("resfile")
    @searchtest.save_result("foobar", tf.path)
    @searchtest.assert_result("foobar", tf.path)
  end

  def tst_poll_compare
    tf = Tempfile.new("resfile")
    @searchtest.save_result("foobar", tf.path)
    @qrserver.set_delay(5)
    @searchtest.poll_compare("foobar", tf.path, nil, [], 10)

    @qrserver.set_delay(10)
    failed = false
    begin
      @searchtest.poll_compare("foobar", tf.path, nil, [], 5)
    rescue AssertionFailedError
      failed = true
    end
    assert(failed, "Test didn't fail when it should have")

  end

  def test_query_errors
    @qrserver.set_error(true)
    @searchtest.assert_query_errors("query=test")
    begin
      @searchtest.assert_query_no_errors("query=test")
    rescue AssertionFailedError
      failed = true
    end
    @qrserver.set_error(false)
    assert(failed, "Test didn't fail when it should have")
  end

  def test_query_no_errors
    @searchtest.assert_query_no_errors("query=test")
    begin
      @searchtest.assert_query_errors("query=test", "No backend in service")
    rescue AssertionFailedError
      failed = true
    end
    assert(failed, "Test didn't fail when it should have")
  end

end
