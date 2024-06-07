# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'
require 'document_set'
require 'search_test'

class FeedWhenContainerOom < SearchTest

  def setup
    @valgrind = false
    set_owner("hmusum")
    set_description("Tests feeding against a container with too little memory to handle feed")

    @feed_file = dirs.tmpdir + "feed.json"
    deploy_app(app())
    set_expected_logged(//, :slow_processing => true)
    start
  end

  def test_feeding_when_container_goes_oom
    doc_count = 5
    generate_feed(doc_count)

    feed(:file => @feed_file, :ignore_errors => true, :stderr => true, :verbose => true, :timeout => 30, :log_config => selfdir + 'logging.properties')
    result = search("sddocname:music")
    assert(result.hitcount < doc_count)

    # Start new feed, will fail until app is redeployed with more memory for container
    feed_thread= Thread.new(){
      feed(:file => @feed_file, :ignore_errors => true, :stderr => true, :verbose => true, :timeout => 150, :log_config => selfdir + 'logging.properties')
    }

    # Sleep to make sure feeder has started before deploy
    sleep 10
    # deploy with more container memory
    deploy_app(app('3g'))
    feed_thread.join
    assert_hitcount("query=sddocname:music", doc_count)
  end

  def app(heap_mem = '1g')
    SearchApp.new.sd(VDS + '/schemas/music.sd').
                 container(Container.new.
                             # Intentionally setup container to have too little memory to handle the 5 large documents => will OOM
                             jvmoptions("-Xms#{heap_mem} -Xmx#{heap_mem}").
                             search(Searching.new).
                             documentapi(ContainerDocumentApi.new))
  end

  def generate_feed(doc_count)
    size = 50000000
    docs = DocumentSet.new
    doc_count.times { |id|
      doc = Document.new("music", "id:test:music:n=" + id.to_s + ":1")
      content = ""
      (size / 50).times {
         content << "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
      }
      doc.add_field("bodyfield", content)
      docs.add(doc)
    }
    docs.write_json(@feed_file)
  end

  def teardown
    stop
  end

end