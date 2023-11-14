# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'docproc_test'
require 'environment'

class ForkOneToZero < DocprocTest

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

  def test_fork_onetozero
    doc1 = Document.new("worst", "id:worst:worst::1234").
      add_field("title", "jalla jalla")
    vespa.document_api_v1.put(doc1, :port => Environment.instance.vespa_web_service_port, :route => "container/chain.onetozero indexing")

    #we should have 0 docs in vds here:
    visitoutput = vespa.adminserver.execute("vespa-visit -i")
    assert_equal(0, $?)
    numdocs = vespa.adminserver.execute("vespa-visit -i | wc -l")
    assert_equal(0, $?)
    assert_equal(0, numdocs.to_i)
  end

  def teardown
    stop
  end

end
