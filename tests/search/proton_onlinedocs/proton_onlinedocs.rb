# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class ProtonOnlineDocs < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def check_online_docs(wanted, timeout)
    num_docs = search("sddocname:test&hits=0&nocache").hitcount
    puts "elastic: num_docs: #{num_docs}"
    assert_equal(wanted, num_docs)
  end

  def test_proton_online_docs
    deploy_app(SearchApp.new.sd("#{selfdir}test.sd"))
    start
    vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on")
    feed_and_wait_for_docs("test", 10, :file => "#{selfdir}docs.xml")
    check_online_docs(10, 120)
  end

  def teardown
    stop
  end

end
