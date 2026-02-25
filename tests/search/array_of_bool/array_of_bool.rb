require 'indexed_streaming_search_test'

class ArrayOfBool < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("Test support for array<bool> field type")
  end

  DOCS = [
    { 'title' => 'tft',    'flags' => [true, false, true] },
    { 'title' => 'ff',     'flags' => [false, false] },
    { 'title' => 'tttf',   'flags' => [true, true, true, false] },
    { 'title' => 'empty',  'flags' => [] },
    { 'title' => 'notset' }
  ]

  def test_array_of_bool
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    DOCS.each_with_index do |fields, i|
      doc = Document.new("id:test:test::#{i}")
      fields.each { |key, value| doc.add_field(key, value) }
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:test', DOCS.size)

    # verify summary rendering
    assert_summary_flags('tft', [true, false, true])
    assert_summary_flags('ff', [false, false])
    assert_summary_flags('tttf', [true, true, true, false])
    assert_summary_flags('empty', nil)
    assert_summary_flags('notset', nil)

    # verify ranking can extract values from bool array
    assert_ranking_flags('tft',  {0 => 1.0, 1 => 0.0, 2 => 1.0, 'count' => 3.0})
    assert_ranking_flags('ff',   {0 => 0.0, 1 => 0.0, 2 => 0.0, 'count' => 2.0})
    assert_ranking_flags('tttf', {0 => 1.0, 1 => 1.0, 2 => 1.0, 'count' => 4.0})
    assert_ranking_flags('empty',  {0 => 0.0, 1 => 0.0, 2 => 0.0, 'count' => 0.0})
    assert_ranking_flags('notset', {0 => 0.0, 1 => 0.0, 2 => 0.0, 'count' => 0.0})
  end

  def assert_summary_flags(title, expected)
    result = search({"yql" => "select * from sources * where title contains '#{title}'"})
    puts "title(#{title}) gives result: #{result.xmldata}"
    assert_equal(1, result.hitcount)
    assert_equal(result.hit[0].field['flags'], expected)
  end

  def assert_ranking_flags(title, expected)
    result = search({"yql" => "select * from sources * where title contains '#{title}'"})
    assert_equal(1, result.hitcount)
    sf = result.hit[0].field['summaryfeatures']
    expected.each do |key, value|
      feature = key == 'count' ? 'attribute(flags).count' : "attribute(flags,#{key})"
      assert_features({feature => value}, sf)
    end
  end

  def teardown
    stop
  end

end
