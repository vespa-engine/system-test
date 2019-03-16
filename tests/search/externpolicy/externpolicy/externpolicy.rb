# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ExternPolicy < IndexedSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir + "music.sd").
                   container(Container.new('extern').
                                 docproc(DocumentProcessing.new.chain(Chain.new('extern')))))
    start
  end

  def test_externPolicy
    assert(feedfile(selfdir + "music.xml",
                    :route => "\"[Extern:tcp/localhost:#{vespa.slobrok["0"].ports[0]};extern/*/chain.extern] default\"").
           include?("/chain.extern"))
  end

  def teardown
    stop
  end

end
