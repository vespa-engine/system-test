# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DocprocDownWhileFeeding < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("Test that feeding is capable of working through a docproc restart.")
    deploy_app(SearchApp.new.sd("#{SEARCH_DATA}/music.sd"))
    start
  end

  def test_restart_docproc_while_feeding
    thread = Thread.new do
      feed(:file => "#{SEARCH_DATA}/music.10000.json",
           :timeout => 120,
           :verbose => true,
           :maxpending => 1)
    end

    sleep 100
    docprocnode = vespa.container.values.first
    docprocnode.stop
    docprocnode.start

    thread.join
    wait_for_hitcount("query=sddocname:music", 10000)
  end

  def teardown
    stop
  end

end
