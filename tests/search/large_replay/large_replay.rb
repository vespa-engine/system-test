# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'document_set'
require 'indexed_only_search_test'

class LargeReplay < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    @valgrind=false
  end

  def timeout_seconds
    60 * 40
  end

  def test_large_replay
    set_description("Test that we can replay a large amount of documents from the transactionlog without interfering with the RPC connection between the service layer and proton persistence provider.")
    deploy_app(SearchApp.new.cluster(SearchCluster.new.sd(selfdir+"test.sd").disable_flush_tuning))
    vespa.adminserver.logctl("searchnode:proton.persistenceengine.persistenceengine", "debug=on")
    start

    num_docs = 800000
    generate_and_feed_docs(num_docs)

    vespa.logserver.delete_vespalog
    vespa.search["search"].first.stop
    vespa.search["search"].first.start
    vespa.adminserver.logctl("searchnode:proton.persistenceengine.persistenceengine", "debug=on")
    vespa.logserver.execute("vespa-logctl searchnode:proton.persistenceengine")
    num_matches = assert_log_matches("Begin initializing persistence handlers", 600)
    assert(1, num_matches)
    wait_for_hitcount("sddocname:test", num_docs, 600)
    assert_log_not_matches("still trying to connect to peer at")
    num_matches = assert_log_matches("Done initializing persistence handlers")
    assert(1, num_matches)
  end


  def generate_and_feed_docs(num_docs)
    feed_file = dirs.tmpdir+"feed.json"

    docs = DocumentSet.new
    for i in 0...num_docs
      doc = Document.new("test", "id:test:test::#{i}").
            add_field("f1", i.to_s).
            add_field("f2", i.to_s)
      docs.add(doc)
    end
    docs.write_xml(feed_file)

    feed_and_wait_for_docs("test", num_docs, :file => feed_file)
  end

  def teardown
    stop
  end

end
