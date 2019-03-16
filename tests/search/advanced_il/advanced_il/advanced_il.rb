# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class AdvancedIL < IndexedSearchTest

  def setup
    set_owner("musum")
    set_description("Test of search definitions containing advanced IL-commands")
    deploy_app(SearchApp.new.sd("#{selfdir}/music.sd"))
    start
  end

  def test_advanced_il
    feed_and_wait_for_docs("music", 10, :file => "#{selfdir}/music.10.xml", :skipfeedtag => true)

    assert_hitcount("query=product:foo", 0)
    assert_hitcount("query=product:bar", 5)
    assert_hitcount("query=product:baz", 2) # if-then evaluates to null if operand is null
    assert_field_matches("query=title:chicago", "my_title", "Chicago Blues")
  end

  def teardown
    stop
  end

end
