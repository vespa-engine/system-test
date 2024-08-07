# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class MbusTimeout < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("This test ensures that messages sent through message bus can expire. It installs a document " +
                    "processor (see SleeperDocProc.java) that sleeps sufficiently long for the client to time out when " +
                    "sending documents and updates. With message expiration, this is detected by message bus so that " +
                    "these updates never reach the search node.")
    add_bundle("#{selfdir}/SleeperDocproc.java")
    deploy_app(SearchApp.new.sd(selfdir + "simple.sd").
	       container(Container.new.
			 search(Searching.new).
			 docproc(DocumentProcessing.new.
				   chain(Chain.new.add(DocProc.new("com.yahoo.vespatest.SleeperDocproc")))).
                         documentapi(ContainerDocumentApi.new)))
    start
  end

  def test_mbusTimeout
    puts("*** Feed initial document.")
    feed_and_wait_for_docs("simple", 1, :file => "#{selfdir}/myfeed.json")

    puts("*** Assert that content of index matches feed.")
    result = search("/?query=myint:777")
    assert_equal(1, result.hit.size)

    puts("*** Feed document update.")
    output = vespa.adminserver.feed(:file => "#{selfdir}/myupdate.json", :timeout => 2, :exceptiononfailure => false, :stderr => true, :client => :vespa_feed_client)

    puts("*** Assert that feeding timed out.")
    assert(output.index("imeout "))

    feed_and_wait_for_docs("simple", 2, :file => "#{selfdir}/mytoken.json")

    puts("*** Assert that content of index did not change.")
    result = search("/?query=myint:777")
    assert_equal(1, result.hit.size)
  end

  def teardown
    stop
  end

end
