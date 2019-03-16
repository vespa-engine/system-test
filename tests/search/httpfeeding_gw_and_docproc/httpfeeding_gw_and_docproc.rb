# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "indexed_search_test"

class HttpfeedingGwAndDocproc < IndexedSearchTest
  def setup
    @feed_file_xml = selfdir + "../data/simple.docs.3.xml"
    @feed_file_json = selfdir + "../data/simple.docs.3.json"
    @feed_file_tas_xml = selfdir + "../data/simple.test-and-set.xml"
    @feed_file_tas_json = selfdir + "../data/simple.test-and-set.json"

    set_owner("valerijf")
    set_description("Test feeding through HTTP client API with document processing in same container, ticket 6390014")
    # app generator didn't include support for building this config at the time
    # of writing
    deploy(selfdir + "setup", selfdir + "../data/simple.sd")
    start
  end

  def test_feed
    require_that_feeding_with_xml_works
    require_that_feeding_with_json_works
    require_that_feeding_with_xml_works_tas
    require_that_feeding_with_json_works_tas
  end

  def require_that_feeding_with_xml_works
    httpclient_feed(@feed_file_xml)
    wait_for_hitcount("query=spiser", 1)
    wait_for_hitcount("query=document2", 1)
    wait_for_hitcount("query=fake", 1)
  end

  def require_that_feeding_with_json_works
    httpclient_feed(@feed_file_json)
    wait_for_hitcount("query=json", 3)
  end

  def require_that_feeding_with_xml_works_tas
    httpclient_feed(@feed_file_tas_xml)
    wait_for_hitcount("query=title:school", 0)
    wait_for_hitcount("query=title:basil", 0)
    wait_for_hitcount("query=title:gundam", 0)
    wait_for_hitcount("query=title:onegai", 1)
    wait_for_hitcount("query=title:elisa", 1)
  end

  def require_that_feeding_with_json_works_tas
    httpclient_feed(@feed_file_tas_json)
    wait_for_hitcount("query=title:school", 0)
    wait_for_hitcount("query=title:basil", 0)
    wait_for_hitcount("query=title:gundam", 0)
    wait_for_hitcount("query=title:onegai", 1)
    wait_for_hitcount("query=title:elisa", 1)
  end

  def httpclient_feed(feed_file)
    feedfile(feed_file, {:client => :vespa_http_client, :route => "indexing"})
  end

  def teardown
    stop
  end
end
