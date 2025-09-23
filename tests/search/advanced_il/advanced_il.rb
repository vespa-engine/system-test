# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class AdvancedIL < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test of search definitions containing advanced IL-commands")
    deploy_app(SearchApp.new.sd("#{selfdir}/music.sd"))
    start
  end

  def test_advanced_il
    feed_and_wait_for_docs("music", 10, :file => "#{selfdir}/music.10.json")

    assert_hitcount("query=product:foo", 0)
    assert_hitcount("query=product:bar", 5)
    assert_hitcount("query=product:baz", 2) # if-then evaluates to null if operand is null
    result = search('query=title:chicago')
    assert(result.hitcount > 0)
    result.hit.each do |h|
      assert(h.field['my_title'] =~ /Chicago Blues/)
    end
  end


end
