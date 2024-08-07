# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'
require 'app_generator/container_app'

class ShoppingUrlCompress < DocprocTest

  def setup
    set_owner("arnej")

    dir = File.expand_path(selfdir)
    puts "bundling '#{dir}'"

    add_bundle_dir(dir, "ShoppingUrls")

    searcher = Searcher.new("UrlDecompressor", nil, nil, "com.yahoo.test.ShoppingUrlSearcher", "ShoppingUrls")
    processor = DocumentProcessor.new("UrlCompressor", "indexingStart", nil, "com.yahoo.test.ShoppingUrlProcessor", "ShoppingUrls")

    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("containercluster1").
                         search(Searching.new.
                                chain(Chain.new("default", "vespa").add(searcher))).
                         docproc(DocumentProcessing.new.
                                 chain(Chain.new("shoppingindexing", "indexing").add(processor))).
                         documentapi(ContainerDocumentApi.new)).
               logserver("node1").
               slobrok("node1").
               search(SearchCluster.new("shopping").sd(selfdir+"app/schemas/shopping.sd").
                      indexing("containercluster1").
                      indexing_chain("shoppingindexing"))
               )

    start
  end

  def test_compress_url
    #feed some docs
    feed_and_wait_for_docs("shopping", 10, :file => selfdir+"feed-init.json")
    assert_result("query=sddocname:shopping&nocache", selfdir+"result-first.json")

    #partial update some docs, add some more
    feed_and_wait_for_docs("shopping", 20, :file => selfdir+"feed-with-updates.json")
    assert_result("query=sddocname:shopping&nocache", selfdir+"result-second.json")
  end

  def teardown
    stop
  end

end
