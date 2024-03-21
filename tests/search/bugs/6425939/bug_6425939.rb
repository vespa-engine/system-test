# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Bug6425939Test < IndexedStreamingSearchTest

  def setup
    set_owner('vekterli')
  end

  def teardown
    stop
  end

  def test_java_document_deserialization_error
    deploy_app(SearchApp.new.
                 cluster_name("cars").
                 sd(selfdir + 'conf/schemas/cars.sd'))
    start

    feed(:file => selfdir + 'singledoc.json')

    vespa.adminserver.execute('vespa-visit')
  end

end
