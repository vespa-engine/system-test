# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'search_test'

require 'streaming_search_test'

class StreamingBongBoldingMatchTest < StreamingSearchTest

  def setup
    super
    set_owner("vekterli")
  end

  def self.testparameters
    { "STREAMING" => { :search_type => "STREAMING" } }
  end

  def test_very_long_juniper_match
    @valgrind=false
    set_owner("vekterli")

    deploy_app(singlenode_streaming_2storage(selfdir+"mail.sd").
                   search_chain(Provider.new("search", "local").
                                   cluster("storage.mail").excludes("com.yahoo.search.searchers.InputCheckingSearcher")))
    start

    feedfile(selfdir+"juniper_bad_doc.json")

    assert_hitcount_with_timeout(60, "streaming.userid=12345678&summary=default&query=%22Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+8RE%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Re%3A+Foo+and+bar%22", 1)
  end

  def teardown
    stop
  end

end
