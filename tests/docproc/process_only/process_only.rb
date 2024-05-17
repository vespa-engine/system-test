# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class ProcessOnly < IndexedStreamingSearchTest
  
  def setup
    set_owner("havardpe")
    set_description("Test that it is valid to feed to docproc for processing without any additional hops.")
    add_bundle("#{selfdir}/MyProcessor.java")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd").
               container(Container.new("default").
                         docproc(DocumentProcessing.new.
                                 chain(Chain.new("default").
                                         add(DocumentProcessor.new("com.yahoo.vespatest.MyProcessor")))).
                         documentapi(ContainerDocumentApi.new)))
    start
  end
  
  def test_process_only
    feedfile("#{selfdir}/feed.json", :route => "default/chain.default")
    wait_for_log_matches(/PROCESSED: id:test:test::/, 10)
  end

  def teardown
    stop
  end

end
