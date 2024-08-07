# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ClearField < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
    set_description("Ensure that clearing a field with an update works.")
  end

  def test_clear_field_mix
    deploy_app(SearchApp.new.sd("#{selfdir}/mix/test.sd"))
    clear_field
  end

  def test_clear_all_attribute
    deploy_app(SearchApp.new.sd("#{selfdir}/all_attribute/test.sd"))
    clear_field
  end

  def clear_field
    start
    feed_and_wait_for_docs("test", 1, :file => "#{selfdir}/feed.json")
    run_query("sddocname:test", "#{selfdir}/full.json")
    feed_and_wait_for_docs("test", 1, :file => "#{selfdir}/clear.json")
    run_query("sddocname:test", "#{selfdir}/cleared.json")
  end

  def run_query(query, file)
    assert_result_with_timeout(5, query, file)
  end

  def teardown
    stop
  end

end
