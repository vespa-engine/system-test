# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'
require 'document_set'
require 'search_test'

class FeedWhenContainerOom < SearchTest

  def setup
    @valgrind = false
    set_owner("hmusum")

    @feed_file = dirs.tmpdir + "feed.json"
    deploy_app(SearchApp.new.sd(VDS + '/schemas/music.sd').
                 container(Container.new.
                             # Too little memory to handle the 5 large documents => will OOM
                             jvmoptions('-Xms1g -Xmx1g').
                             search(Searching.new).
                             documentapi(ContainerDocumentApi.new)))
    set_expected_logged(//, :slow_processing => true)
    start
  end

  def timeout_seconds
    120
  end

  def test_feeding_when_container_goes_oom
     count = 5
     size = 50000000

     feed_and_verify(count, size)
  end

  def feed_and_verify(count, size)
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
    feed_and_wait_for_docs("music", 5, :file => @feed_file, :stderr => true, :verbose => true, :timeout => 60, :log_config => selfdir + 'logging.properties')
  end

  def teardown
    stop
  end

end
