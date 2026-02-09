require 'indexed_only_search_test'

class ArrayOfBool < IndexedOnlySearchTest

  def setup
    set_owner("havardpe")
    set_description("Test support for array<bool> field type")
  end

  def test_array_of_bool
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "feed.json")

    # verify summary rendering
    assert_summary_flags('tft', [true, false, true])
    assert_summary_flags('ff', [false, false])
    assert_summary_flags('tttf', [true, true, true, false])
    assert_summary_flags('empty', nil)
    assert_summary_flags('notset', nil)
  end

  def assert_summary_flags(title, expected)
    result = search({"yql" => "select * from sources * where title contains '#{title}'"})
    puts "title(#{title}) gives result: #{result.xmldata}"
    assert_equal(1, result.hitcount)
    assert_equal(result.hit[0].field['flags'], expected)
  end

  def teardown
    stop
  end

end
