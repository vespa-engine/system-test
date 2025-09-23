# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'
require 'environment'

class ForkOneToOne < DocprocTest

  def setup
    set_owner("gjoranv")
    set_description("Test that docproc is truly message-agnostic.")
    add_bundle(selfdir+"OneToManyDocumentsAllInSameBucketProcessor.java")
    add_bundle(selfdir+"OneToManyDocumentsProcessor.java")
    add_bundle(selfdir+"OneToManyDocumentsSomeInSameBucketProcessor.java")
    add_bundle(selfdir+"OneToOneDocumentProcessor.java")
    add_bundle(selfdir+"OneToZeroDocumentsProcessor.java")
    deploy(selfdir+"app", DOCPROC+"data/worst.sd")
    start
  end

  def test_fork_onetoone
    doc1 = Document.new("id:worst:worst::1234").
      add_field("title", "jalla jalla")
    vespa.document_api_v1.put(doc1, :port => Environment.instance.vespa_web_service_port, :route => "container/chain.onetoone indexing")

    #we should have 1 doc in vds here:
    visitoutput = vespa.adminserver.execute("vespa-visit -i")
    assert_equal(0, $?)
    numdocs = vespa.adminserver.execute("vespa-visit -i | wc -l")
    assert_equal(0, $?)
    assert_equal(1, numdocs.to_i)

    doc1 = vespa.document_api_v1.get("id:worst:worst::1234", :port => Environment.instance.vespa_web_service_port)
    assert_equal("jalla jalla", doc1.fields["title"])
  end


end
