# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class AttributePostinglistUpdateTest < IndexedOnlySearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("geirst")
  end

  def test_attribute_postinglist_update
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    set_description("Verify that posting list is correctly updated when attribute has multiple terms that share posting list")
    start

    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    assert_hitcount("query=str_array:foo", 1)
    assert_hitcount("query=int_array:7", 1)

    feed(:file => selfdir + "update.json")
    assert_hitcount("query=str_array:foo", 1)
    assert_hitcount("query=int_array:7", 1)
  end


end
