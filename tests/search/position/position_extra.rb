# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class PositionExtra < IndexedOnlySearchTest

  SAVE_RESULT = false

  def setup
    set_owner('arnej')
    set_description('Ensure that position indexing works with field outside document.')
  end

  def test_position_extra
    run_test('extra', 4)
  end

  def run_test(type, hits)
    deploy_app(SearchApp.new.sd("#{selfdir}/#{type}_pos.sd"))
    start
    feed_and_wait_for_docs("#{type}_pos", hits, :file => "#{selfdir}/#{type}_feed.xml")
    run_query('yql=select * from sources * where geoLocation("my_pos", 12.123000, 98.987000, "500 km")',
              "#{selfdir}/#{type}_result1.json");
    run_query('yql=select * from sources * where geoLocation("my_pos", 12.123123, 98.987987, "500 km")',
              "#{selfdir}/#{type}_result2.json");
  end

  def run_query(query, file)
    if (SAVE_RESULT)
      save_result(query, file)
    else
      assert_result(query, file)
    end
  end

  def teardown
    stop
  end

end
