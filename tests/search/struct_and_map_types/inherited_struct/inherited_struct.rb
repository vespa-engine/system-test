# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class InheritedStruct < IndexedStreamingSearchTest

  def setup
    set_owner('balder')
    set_description('Test that structs can be used in inherited types.')
  end

  # Use structs with various inheritance
  def test_structs_are_inherited
    deploy_app(SearchApp.new.
                      sd(selfdir + 'concretedocs/base.sd').
                      sd(selfdir + 'concretedocs/usebase.sd'))
    start
    feed(:file => selfdir + 'docs.json')
    vespa.adminserver.execute('vespa-visit')
    assert_hitcount('query=sddocname:usebase', 1)
  end

  # Use structs with various inheritance in concrete document types
  def test_inherited_structs_in_concrete_docs
    add_bundle_dir(File.expand_path(selfdir + '/concretedocs'), 'inheritedconcretedocs')
    mydp = DocumentProcessor.new('concretedocs.ConcreteDocDocProc', 'indexingStart').bundle('inheritedconcretedocs')
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new.
                       sd(selfdir + 'concretedocs/base.sd').
                       sd(selfdir + 'concretedocs/usebase.sd').
                       indexing('dpclust').
                       indexing_chain('mydpchain')).
               container(Container.new('dpclust').
                         search(Searching.new).
                         concretedoc(ConcreteDoc.new('usebase').bundle('inheritedconcretedocs')).
                         docproc(DocumentProcessing.new.
                                 chain(Chain.new('mydpchain', 'indexing').
                                       add(mydp)))))
    start
    feed(:file => selfdir + 'docs.json')
    vespa.adminserver.execute('vespa-visit')
    assert_hitcount('query=sddocname:usebase', 1)
    vespa.adminserver.execute('vespa-logfmt | grep CDDP')
  end

  def teardown
    stop
  end

end
