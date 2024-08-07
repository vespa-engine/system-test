# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'
require 'environment'

class ForkOneToManySomeInSameBucket < DocprocTest

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

  def test_fork_onetomanysomeinsamebucket
    doc1 = Document.new("worst", "id:worst:worst::1234").
      add_field("title", "jalla jalla")
    puts "created doc"
    vespa.document_api_v1.put(doc1, :port => Environment.instance.vespa_web_service_port, :route => "container/chain.onetomanysomeinsamebucket indexing")

    #we should have 10 docs in vds here:
    visitoutput = vespa.adminserver.execute("vespa-visit -i")
    assert_equal(0, $?)
    numdocs = vespa.adminserver.execute("vespa-visit -i | wc -l")
    assert_equal(0, $?)
    assert_equal(10, numdocs.to_i)

    doc1 = vespa.document_api_v1.get("id:123456:worst:n=7890:balla:er:bra", :port => Environment.instance.vespa_web_service_port)
    assert(doc1 != nil)
    doc2 = vespa.document_api_v1.get("id:123456:worst:n=7890:a:a", :port => Environment.instance.vespa_web_service_port)
    assert(doc2 != nil)
    doc3 = vespa.document_api_v1.get("id:123456:worst:n=7890:balla:tralsfa", :port => Environment.instance.vespa_web_service_port)
    assert(doc3 != nil)
    doc4 = vespa.document_api_v1.get("id:567890:worst:n=1234:a", :port => Environment.instance.vespa_web_service_port)
    assert(doc4 != nil)
    doc5 = vespa.document_api_v1.get("id:567890:worst:n=1234:balla:ala", :port => Environment.instance.vespa_web_service_port)
    assert(doc5 != nil)
    doc6 = vespa.document_api_v1.get("id:jalla:worst::balla:er:ja", :port => Environment.instance.vespa_web_service_port)
    assert(doc6 != nil)
    doc7 = vespa.document_api_v1.get("id:jalla:worst::balla:hahahhaa", :port => Environment.instance.vespa_web_service_port)
    assert(doc7 != nil)
    doc8 = vespa.document_api_v1.get("id:jalla:worst::balla:aa", :port => Environment.instance.vespa_web_service_port)
    assert(doc8 != nil)
    doc9 = vespa.document_api_v1.get("id:jalla:worst::balla:sdfgsaa", :port => Environment.instance.vespa_web_service_port)
    assert(doc9 != nil)
    doc10 = vespa.document_api_v1.get("id:jalla:worst::balla:dfshaa", :port => Environment.instance.vespa_web_service_port)
    assert(doc10 != nil)
  end

  def teardown
    stop
  end

end
