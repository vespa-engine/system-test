# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'
require 'environment'

class ForkOneToMany < DocprocTest

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

  def test_fork_onetomany
    doc1 = Document.new("id:worst:worst::1234").
      add_field("title", "jalla jalla")
    puts "created doc"
    vespa.document_api_v1.put(doc1, :port => Environment.instance.vespa_web_service_port, :route => "container/chain.onetomany indexing")

    #we should have 4 docs in vds here:
    visitoutput = vespa.adminserver.execute("vespa-visit -i")
    assert_equal(0, $?)
    numdocs = vespa.adminserver.execute("vespa-visit -i | wc -l")
    assert_equal(0, $?)
    assert_equal(4, numdocs.to_i)

    doc1 = vespa.document_api_v1.get("id:jalla:worst::balla:er:bra", :port => Environment.instance.vespa_web_service_port)
    assert(doc1 != nil)
    doc2 = vespa.document_api_v1.get("id:jalla:worst::balla:er:ja", :port => Environment.instance.vespa_web_service_port)
    assert(doc2 != nil)
    doc3 = vespa.document_api_v1.get("id:jalla:worst::balla:trallala", :port => Environment.instance.vespa_web_service_port)
    assert(doc3 != nil)
    doc4 = vespa.document_api_v1.get("id:jalla:worst::balla:hahahhaa", :port => Environment.instance.vespa_web_service_port)
    assert(doc4 != nil)
  end

  def teardown
    stop
  end

end
