# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class SearcherHttpHeaders < SearchContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Verify that it is indeed possible to set HTTP headers in a searcher, and verify that Date header is sane.")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.container.test.httpheaders.HttpHeaderSettingSearcher")
    output = deploy(selfdir+"app")
    start
  end

  def test_httpheaders
    assert_httpresponse("/?query=hans&timeout=86400s", {}, responsecode = 200, { "Cache-Control" => ["max-age=120", "min-fresh=60"],
                                                                                  "Expires" => "120" })

    dateformat = /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d\d\d\d \d\d:\d\d:\d\d GMT$/
    assert_httpresponse_regexp("/?query=hans&timeout=86400s", {}, responsecode = 200, { "Date" => dateformat })
  end

  def teardown
    stop
  end

end
