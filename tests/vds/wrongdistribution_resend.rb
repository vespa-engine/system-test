# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class WrongDistributionResend < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def test_wrongdistribution
    vespa.storage["storage"].distributor["1"].stop

    # Feed some documents, some should be rejected by storage nodes
    # as they don't know that the distributor is down.
    for i in 1..100
      doc = Document.new("music", "id:crawler:music::http://yahoo.com/storage_test" + i.to_s)
      vespa.document_api_v1.put(doc)
    end
  end

  def teardown
    stop
  end
end

