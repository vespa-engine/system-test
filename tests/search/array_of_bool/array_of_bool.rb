require 'indexed_streaming_search_test'

class ArrayOfBool < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("Test support for array<bool> field type")
  end

  TITLES = ['tft', 'ff', 'tttf', 'empty', 'notset']

  def make_flags(title)
    return nil if title == 'notset'
    return [] if title == 'empty'
    title.chars.map { |c| c == 't' }
  end

  def make_arr(title)
    return nil if title == 'notset'
    return [] if title == 'empty'
    title.chars.map { |c| { 'tag' => c, 'flag' => c == 't' } }
  end

  def make_mymap(title, offset = 0)
    return nil if title == 'notset'
    return {} if title == 'empty'
    result = {}
    title.chars.each_with_index { |c, i| result[(offset + i).to_s] = { 'tag' => c, 'flag' => c == 't' } }
    result
  end

  def make_flagmap(title, offset = 0)
    return nil if title == 'notset'
    return {} if title == 'empty'
    result = {}
    title.chars.each_with_index { |c, i| result[(offset + i).to_s] = (c == 't') }
    result
  end

  def make_features(name, title)
    flags = make_flags(title) || []
    result = {"attribute(#{name}).count" => flags.size.to_f}
    5.times do |i|
      val = (i < flags.size && flags[i]) ? 1.0 : 0.0
      result["attribute(#{name},#{i})"] = val
    end
    result
  end

  def test_make_helpers
    assert_equal([true, false, true], make_flags('tft'))
    assert_equal([false, false], make_flags('ff'))
    assert_equal([], make_flags('empty'))
    assert_equal(nil, make_flags('notset'))

    assert_equal([{'tag' => 't', 'flag' => true}, {'tag' => 'f', 'flag' => false}, {'tag' => 't', 'flag' => true}], make_arr('tft'))
    assert_equal([{'tag' => 'f', 'flag' => false}, {'tag' => 'f', 'flag' => false}], make_arr('ff'))
    assert_equal([], make_arr('empty'))
    assert_equal(nil, make_arr('notset'))

    assert_equal({'0' => {'tag' => 't', 'flag' => true}, '1' => {'tag' => 'f', 'flag' => false}, '2' => {'tag' => 't', 'flag' => true}}, make_mymap('tft'))
    assert_equal({'0' => {'tag' => 'f', 'flag' => false}, '1' => {'tag' => 'f', 'flag' => false}}, make_mymap('ff'))
    assert_equal({}, make_mymap('empty'))
    assert_equal(nil, make_mymap('notset'))
    assert_equal({'3' => {'tag' => 't', 'flag' => true}}, make_mymap('t', 3))

    assert_equal({'0' => true, '1' => false, '2' => true}, make_flagmap('tft'))
    assert_equal({'0' => false, '1' => false}, make_flagmap('ff'))
    assert_equal({}, make_flagmap('empty'))
    assert_equal(nil, make_flagmap('notset'))
    assert_equal({'3' => true}, make_flagmap('t', 3))

    assert_equal({'attribute(flags).count' => 3.0,
                  'attribute(flags,0)' => 1.0, 'attribute(flags,1)' => 0.0, 'attribute(flags,2)' => 1.0,
                  'attribute(flags,3)' => 0.0, 'attribute(flags,4)' => 0.0}, make_features('flags', 'tft'))
    assert_equal({'attribute(flags).count' => 0.0,
                  'attribute(flags,0)' => 0.0, 'attribute(flags,1)' => 0.0, 'attribute(flags,2)' => 0.0,
                  'attribute(flags,3)' => 0.0, 'attribute(flags,4)' => 0.0}, make_features('flags', 'empty'))
    assert_equal({'attribute(flags).count' => 0.0,
                  'attribute(flags,0)' => 0.0, 'attribute(flags,1)' => 0.0, 'attribute(flags,2)' => 0.0,
                  'attribute(flags,3)' => 0.0, 'attribute(flags,4)' => 0.0}, make_features('flags', 'notset'))
  end

  def feed_docs
    unless is_streaming
      TITLES.each_with_index do |title, i|
        parent = Document.new("id:test:parent::#{i}")
        flags = make_flags(title)
        parent.add_field('flags', flags) unless flags.nil?
        vespa.document_api_v1.put(parent)
      end
    end
    TITLES.each_with_index do |title, i|
      doc = Document.new("id:test:test::#{i}")
      doc.add_field('title', title)
      doc.add_field('parent_ref', "id:test:parent::#{i}") unless is_streaming
      flags = make_flags(title)
      arr = make_arr(title)
      mymap = make_mymap(title)
      flagmap = make_flagmap(title)
      doc.add_field('flags', flags) unless flags.nil?
      doc.add_field('arr', arr) unless arr.nil?
      doc.add_field('mymap', mymap) unless mymap.nil?
      doc.add_field('flagmap', flagmap) unless flagmap.nil?
      vespa.document_api_v1.put(doc)
    end
    wait_for_hitcount('?query=sddocname:test', TITLES.size)
  end

  def assert_fields(search_title, expected_title)
    assert_summary_field(search_title, 'flags', make_flags(expected_title))
    assert_summary_field(search_title, 'arr', make_arr(expected_title))
    assert_summary_field(search_title, 'mymap', make_mymap(expected_title))
    assert_summary_field(search_title, 'flagmap', make_flagmap(expected_title))
    assert_ranking_flags(search_title, make_features('flags', expected_title))
    assert_ranking_flags(search_title, make_features('arr.flag', expected_title))
    assert_map_ranking_flags(search_title, 'mymap.value.flag', 'mymap.key', expected_title)
    assert_map_ranking_flags(search_title, 'flagmap.value', 'flagmap.key', expected_title)
    unless is_streaming
      assert_summary_field(search_title, 'parent_flags', make_flags(search_title))
      assert_ranking_flags(search_title, make_features('parent_flags', search_title))
    end
  end

  def make_app
    app = SearchApp.new
    if is_streaming
      app.sd(selfdir + "streaming/test.sd")
    else
      app.sd(selfdir + "parent.sd", { :global => true }).sd(selfdir + "indexed/test.sd")
    end
  end

  def test_array_of_bool
    deploy_app(make_app)
    start
    feed_docs
    TITLES.each { |title| assert_fields(title, title) }
  end

  def test_partial_update
    deploy_app(make_app)
    start
    feed_docs

    do_assign(0, 'ft')
    assert_fields('tft', 'ft')

    do_assign(1, 'empty')
    assert_fields('ff', 'empty')

    do_assign(4, 'tf')
    assert_fields('notset', 'tf')

    do_add(2, 'tttf', 't')
    assert_fields('tttf', 'tttft')
  end

  def do_assign(doc_id, new_title)
    upd = DocumentUpdate.new("test", "id:test:test::#{doc_id}")
    upd.addOperation("assign", "flags", make_flags(new_title) || [])
    upd.addOperation("assign", "arr", make_arr(new_title) || [])
    upd.addOperation("assign", "mymap", make_mymap(new_title) || {})
    upd.addOperation("assign", "flagmap", make_flagmap(new_title) || {})
    vespa.document_api_v1.update(upd)
  end

  def do_add(doc_id, old_title, add_title)
    offset = old_title.length
    upd = DocumentUpdate.new("test", "id:test:test::#{doc_id}")
    upd.addOperation("add", "flags", make_flags(add_title))
    upd.addOperation("add", "arr", make_arr(add_title))
    make_flagmap(add_title, offset).each { |k, v| upd.addOperation("assign", "flagmap{#{k}}", v) }
    make_mymap(add_title, offset).each { |k, v| upd.addOperation("assign", "mymap{#{k}}", v) }
    vespa.document_api_v1.update(upd)
  end

  def assert_summary_field(title, field, expected)
    expected = nil if expected.is_a?(Array) && expected.empty?
    expected = nil if expected.is_a?(Hash) && expected.empty?
    result = search({"yql" => "select * from sources * where title contains '#{title}'"})
    assert_equal(1, result.hitcount)
    assert_equal(expected, result.hit[0].field[field])
  end

  def assert_map_ranking_flags(search_title, flag_name, key_name, expected_title)
    flags = make_flags(expected_title) || []
    result = search({"yql" => "select * from sources * where title contains '#{search_title}'"})
    assert_equal(1, result.hitcount)
    sf = result.hit[0].field['summaryfeatures']
    expected = {
      "attribute(#{flag_name}).count" => flags.size.to_f,
      "attribute(#{key_name}).count" => flags.size.to_f
    }
    5.times do |i|
      if i < flags.size
        key = sf["attribute(#{key_name},#{i})"].to_i
        expected["attribute(#{flag_name},#{i})"] = flags[key] ? 1.0 : 0.0
      else
        expected["attribute(#{flag_name},#{i})"] = 0.0
        expected["attribute(#{key_name},#{i})"] = 0.0
      end
    end
    assert_features(expected, sf)
  end

  def assert_ranking_flags(title, expected)
    result = search({"yql" => "select * from sources * where title contains '#{title}'"})
    assert_equal(1, result.hitcount)
    assert_features(expected, result.hit[0].field['summaryfeatures'])
  end

  def teardown
    stop
  end

end
