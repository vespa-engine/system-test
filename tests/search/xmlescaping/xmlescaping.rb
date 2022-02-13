# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class XMLEscaping < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_xml_escaping
    set_description("Test that '&', '<', and '>' are escaped correctly in document summary.")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "feed.xml")

    assert_result("query=sddocname:test", selfdir + "result.json", nil, ["a", "b", "c", "d", "e", "f"])
  end

  def teardown
    stop
  end

end
