# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'document'
require 'document_set'
require 'indexed_streaming_search_test'

class FeedDuringReconfig < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def timeout_seconds
    60 * 20
  end

  def generate_documents(docid_begin, num_docs)
    ds = DocumentSet.new()
    for i in docid_begin...docid_begin + num_docs do
      doc = Document.new("test", "id:test:test::" + "%05d" % i)
      doc.add_field("f1", "But if you meet a friendly horse. Will you communicate by morse?")
      doc.add_field("tags", [["No, I speak only kaudervelsk", 1], ["No, I speak only kaudervelsk", 2], ["No, I speak only kaudervelsk", 3]])
      doc.add_field("wset", [["No, I speak only kaudervelsk", 1], ["No, I speak only kaudervelsk", 2], ["No, I speak only kaudervelsk", 3]])
      doc.add_field("arraystring", ["No, I speak only kaudervelsk", "No, I speak only kaudervelsk", "No, I speak only kaudervelsk"])
      ds.add(doc)
    end
    return ds
  end

  def redeploy(sd_num)
    node = vespa.search["search"].first
    sd_file = "sd.#{sd_num}/test.sd"
    puts "About to redeploy: #{sd_file}"
    deploy_output = super(SearchApp.new.sd(selfdir + sd_file))
    wait_for_application(vespa.container.values.first, deploy_output)
  end

  def test_put_feed_during_reconfig
    set_description("Test that we can feed document puts while doing reconfig")
    deploy_app(SearchApp.new.sd(selfdir + "sd.0/test.sd"))
    start

    @feed_file = dirs.tmpdir + "temp.feed.xml"
    generate_documents(0, 50000).write_xml(@feed_file)
    @mutex = Mutex.new
    @should_feed = true
    thread = Thread.new do
      begin
        while true
          break if !@mutex.synchronize { @should_feed }
          feed_and_wait_for_docs("test", 50000, :file => @feed_file)
        end
      rescue => ex
        puts "Feed thread exception message: #{ex.message}"
        puts "Feed thread exception backtrace: #{ex.backtrace.join("\n")}"
      end
    end
    sd_num = 1
    10.times do
      redeploy(sd_num % 2)
      sd_num += 1
    end
    @mutex.synchronize {
      @should_feed = false
    }
    thread.join
  end

  def teardown
    stop
  end

end
