# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Bug4711376 < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
    set_description("Test bug 4711376")
  end

  def test_bug4711376
    app = SearchApp.new.sd(selfdir + "base.sd").
          cluster(SearchCluster.new("image").sd(selfdir + "image.sd")).
          cluster(SearchCluster.new("music").sd(selfdir + "music.sd")).
          storage(StorageCluster.new("storage", 1).
                  sd(selfdir + "image.sd").
                  sd(selfdir + "music.sd").
                  group(NodeGroup.new(0, "mycluster").default_nodes(1, 0)))
    deploy_app(app)
    start
    feed(:file => selfdir+"combineddata.json")
    query = "?query=sddocname:image sddocname:music&type=any&sorting=-uca(comment) title"
    for i in 1...3 do
        search_with_timeout(20, query)
    end
    assert_result(query, selfdir + "result.json")
  end

  def teardown
    stop
  end

end
