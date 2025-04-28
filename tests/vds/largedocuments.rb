# Copyright Vespa.ai. All rights reserved.
require 'app_generator/search_app'
require 'document_set'
require 'vds_test'

class LargeDocuments < VdsTest

  def setup
    @valgrind = false
    set_owner("vekterli")

    @feed_file = dirs.tmpdir + "feed.json"
    deploy_app(SearchApp.new.sd(VDS + '/schemas/music.sd').
                 container(Container.new.
                             # Needs more memory due to large documents
                             jvmoptions('-Xms3g -Xmx3g').
                             search(Searching.new).
                             documentapi(ContainerDocumentApi.new)))
    set_expected_logged(//, :slow_processing => true)
    start
  end

  def target_node
    vespa.search["search"].first
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
      doc = Document.new("id:test:music:n=" + id.to_s + ":1")
      content = ""
      (size / 50).times {
         content << "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
      }
      doc.add_field("bodyfield", content)
      docs.add(doc)
    }
    docs.write_json(@feed_file)
    feed(:file => @feed_file)
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

