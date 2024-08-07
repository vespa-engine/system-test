# Copyright Vespa.ai. All rights reserved.
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
