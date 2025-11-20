# Copyright Vespa.ai. All rights reserved.
require 'app_generator/search_app'
require 'document_set'
require 'search_test'

class FeedWhenContainerOom < SearchTest

  def setup
    set_owner("hmusum")
    set_description("Tests feeding against a container with too little memory to handle feed")
    set_expected_logged(//, :slow_processing => true)

    @valgrind = false
    @feed_file = dirs.tmpdir + "feed.json"
  end

  def test_feeding_when_container_goes_oom
    doc_count = 10
    generate_feed(doc_count)

    # Deploy app with container with too little memory to feed (large documents) => will OOM
    deploy_app(app('1g'))
    start
    feed_file(@feed_file, 30)
    result = search("sddocname:music")
    assert(result.hitcount < doc_count, "Expected hitcount in result (#{result.hitcount}) to be less than #{doc_count}, result: #{result}")

    # Start new feed, will fail until app is redeployed with more memory for container
    feed_thread = Thread.new(){
      feed_file(@feed_file, 150)
    }

    # Wait until feeder has started before deploying
    start = Time.now()
    loop do
      break if feed_thread.status == 'run'
      raise "Feed thread not running after 10 seconds" if Time.now > start + 10.seconds
      sleep 0.01
    end

    # deploy app with more container memory, feed should succeed
    deploy_app(app('3g'))
    feed_thread.join
    wait_for_hitcount("query=sddocname:music", doc_count, 30)
  end

  def app(heap_mem)
    SearchApp.new.sd(VDS + '/schemas/music.sd').
                 container(Container.new.
                             jvmoptions("-Xms#{heap_mem} -Xmx#{heap_mem}").
                             search(Searching.new).
                             documentapi(ContainerDocumentApi.new))
  end

  def generate_feed(doc_count)
    size = 50000000
    docs = DocumentSet.new
    doc_count.times { |id|
      doc = Document.new("id:test:music:n=" + id.to_s + ":1")
      content = ""
      (size / 50).times {
         content << "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n"
      }
      doc.add_field("bodyfield", content)
      docs.add(doc)
    }
    docs.write_json(@feed_file)
  end


  def feed_file(feed_file, timeout = 30, verbose = false)
    params = {:file => feed_file, :ignore_errors => true, :stderr => true, :verbose => verbose, :timeout => timeout}
    params.merge({:log_config => selfdir + 'logging.properties'}) if verbose
    feed(params)
  end

end
