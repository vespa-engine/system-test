# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class BoldingMultipleFieldsTest < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
  end

  def my_search(query)
    form = [['model.type', 'all'],
            ["query", query],
            ["summary", @summary]]
    encoded_query = URI.encode_www_form(form)
    return search(encoded_query)
  end

  def assert_fields(query, exp_fields)
    result = my_search(query)
    assert_equal(1, result.hitcount)
    fields = result.hit[0].field
    puts "fields for query '#{query}' are #{fields}"
    assert_equal(exp_fields[0], fields[@field_names[0]])
    assert_equal(exp_fields[1], fields[@field_names[1]])
    assert_equal(exp_fields[2], fields[@field_names[2]])
  end

  def run_test_bolding_multiple_fields(renamed_fields)
    if renamed_fields
      @subdir = 'multiple-fields-renamed'
      @field_names = [ 'a2', 'b2', 'c2' ]
      @summary = 'renamed'
    else
      @subdir = 'multiple-fields'
      @field_names = [ 'a', 'b', 'c' ]
      @summary = 'default'
    end
    exp_bold_none = "one two three"
    exp_bold_one = "<hi>one</hi> two three"
    exp_bold_two = "one <hi>two</hi> three"
    exp_bold_three = "one two <hi>three</hi>"
    exp_bold_two_substring = "one t<hi>w</hi>o three"
    deploy_app(SearchApp.new.sd(selfdir+"#{@subdir}/test.sd"))
    start
    feed(:file => selfdir + "#{@subdir}/doc.json")
    assert_fields("one", [ exp_bold_one, exp_bold_one, exp_bold_none])
    assert_fields("two", [ exp_bold_two, exp_bold_two, exp_bold_none])
    assert_fields("three", [ exp_bold_three, exp_bold_three, exp_bold_none])
    assert_fields("ab:one", [ exp_bold_one, exp_bold_one, exp_bold_none])
    assert_fields("ab:two", [ exp_bold_two, exp_bold_two, exp_bold_none])
    assert_fields("ab:three", [ exp_bold_three, exp_bold_three, exp_bold_none])
    assert_fields("a:one", [ exp_bold_one, exp_bold_none, exp_bold_none])
    assert_fields("a:two", [ exp_bold_two, exp_bold_none, exp_bold_none])
    assert_fields("a:three", [ exp_bold_three, exp_bold_none, exp_bold_none])
    assert_fields("b:one", [ exp_bold_none, exp_bold_one, exp_bold_none])
    assert_fields("b:two", [ exp_bold_none, exp_bold_two, exp_bold_none])
    assert_fields("b:three", [ exp_bold_none, exp_bold_three, exp_bold_none])
    assert_fields("c:one", [ exp_bold_none, exp_bold_none, exp_bold_none])
    assert_fields("c:two", [ exp_bold_none, exp_bold_none, exp_bold_none])
    assert_fields("c:three", [ exp_bold_none, exp_bold_none, exp_bold_none])
    assert_fields("ac:one", [ exp_bold_one, exp_bold_none, exp_bold_none])
    assert_fields("ac:two", [ exp_bold_two, exp_bold_none, exp_bold_none])
    assert_fields("ac:three", [ exp_bold_three, exp_bold_none, exp_bold_none])
    assert_fields("bc:one", [ exp_bold_none, exp_bold_one, exp_bold_none])
    assert_fields("bc:two", [ exp_bold_none, exp_bold_two, exp_bold_none])
    assert_fields("bc:three", [ exp_bold_none, exp_bold_three, exp_bold_none])
    if is_streaming
      assert_fields("*w*", [ exp_bold_two_substring, exp_bold_two_substring, exp_bold_none])
      assert_fields("ab:*w*", [ exp_bold_two_substring, exp_bold_two_substring, exp_bold_none])
      assert_fields("a:*w*", [ exp_bold_two_substring, exp_bold_none, exp_bold_none])
      assert_fields("b:*w*", [ exp_bold_none, exp_bold_two_substring, exp_bold_none])
      assert_fields("c:*w*", [ exp_bold_none, exp_bold_none, exp_bold_none])
      assert_fields("ac:*w*", [ exp_bold_two_substring, exp_bold_none, exp_bold_none])
      assert_fields("bc:*w*", [ exp_bold_none, exp_bold_two_substring, exp_bold_none])
    end
  end

  def test_bolding_multiple_fields
    run_test_bolding_multiple_fields(false)
  end

  def test_bolding_multiple_fields_renamed
    run_test_bolding_multiple_fields(true)
  end

  def teardown
    stop
  end
end
