# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ExternPolicy < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.
                 sd(selfdir + "music.sd").
                 container(Container.new('extern').
                             docproc(DocumentProcessing.new.chain(Chain.new('extern'))).
                             documentapi(ContainerDocumentApi.new)))
    start
  end

  def test_externPolicy
    assert(feedfile(selfdir + "music.json",
                    :route => "\"[Extern:tcp/localhost:#{vespa.slobrok["0"].ports[0]};extern/*/chain.extern] default\"",
                    :show_all => true,
                    :trace => 5).
           include?("/chain.extern"))
  end

  def teardown
    stop
  end

end
