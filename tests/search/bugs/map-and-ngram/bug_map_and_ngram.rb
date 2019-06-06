# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'environment'

class MapAndNgramBug < SearchTest

  def setup
    set_owner("arnej")
  end

  def test_map_and_ngram
    deploy_app(
        ContainerApp.new.
               container(Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      num_parts(1).redundancy(1).ready_copies(1).
                      sd(selfdir+"foo.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("foo", 3, :file => selfdir+"feed.xml")

    node = vespa.adminserver
    node.copy(selfdir + "updates.json", dirs.tmpdir)
    node.execute("cd #{dirs.tmpdir} && vespa-feeder --trace 4 --maxpending 1 updates.json");
  end

  def teardown
    stop
  end

end
