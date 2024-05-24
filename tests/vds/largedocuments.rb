# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document_set'
require 'vds_test'

class LargeDocuments < VdsTest

  def setup
    @valgrind = false
    set_owner("vekterli")

    @feed_file = dirs.tmpdir + "feed.json"
    deploy_app(default_app)
    set_expected_logged(//, :slow_processing => true)
    start
  end

  def timeout_seconds
    1200
  end

  def target_node
    vespa.storage["storage"].distributor["0"]
  end

  def test_largedocuments
     count = 5
     size = 50000000

     create_dummy_feed(count, size)
     assert(check_dummy_feed(count, size))
  end

  def create_dummy_feed(count, size)
    docs = DocumentSet.new
    count.times { |id|
      doc = Document.new("music", "id:test:music:n=" + id.to_s + ":1")
      content = ""
      (size / 50).times {
         content << "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
      }
      doc.add_field("bodyfield", content)
      docs.add(doc)
    }
    docs.write_json(@feed_file)
    feed(:file => @feed_file, :stderr => true, :verbose => true)
  end

  def check_dummy_feed(count, size)
    count.times { |id|
      documentid="id:test:music:n=" + id.to_s + ":1"
      bytes = target_node.execute("vespa-get " + documentid + " | wc -c").to_i

      return false if bytes < size
    }

    bytes = target_node.execute("vespa-visit --maxpending 1 --maxpendingsuperbuckets 1 --maxbuckets 1 | wc -c").to_i
    bytes >= (size * count)
  end

  def teardown
    stop
  end

end

