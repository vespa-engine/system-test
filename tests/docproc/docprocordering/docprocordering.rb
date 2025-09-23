# Copyright Vespa.ai. All rights reserved.

require 'docproc_test'

class DocprocOrdering < DocprocTest

  def setup
    set_owner("gjoranv")
    base = add_bundle_dir(File.expand_path(selfdir) + "/order_document_processor",
                          "com.yahoo.vespatest.order.OrderDocumentProcessor")
    add_bundle(selfdir+"/FirstDocumentProcessor.java", :dependencies => [base])
    add_bundle(selfdir+"/SecondDocumentProcessor.java", :dependencies => [base])
    add_bundle(selfdir+"/ThirdDocumentProcessor.java", :dependencies => [base])
    add_bundle(selfdir+"/FourthDocumentProcessor.java", :dependencies => [base])
    add_bundle(selfdir+"/FifthDocumentProcessor.java", :dependencies => [base])
    deploy(selfdir+"app")
    start
  end

  def test_docproc_ordering
    feed_and_wait_for_docs("docprocordering", 1, {:file => selfdir+"docprocordering.1.json"})
  end


end
