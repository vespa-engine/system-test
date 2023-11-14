# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'docproc_test'

class DocprocComponentDocprocClustersDocprocChains < DocprocTest

  def setup
    set_owner("havardpe")
    set_description("Verifies that it is possible to set up multiple docproc clusters, running common and separate docproc chains.")
  end

  def use_multitenant_configservers?(method_name=nil)
    false
  end

  def test_docproc_component_docprocclusters_docprocchains
    clear_bundles()
    add_bundle_dir(selfdir, "com.yahoo.vespatest.ExtraHitDocumentProcessor")
    deploy(selfdir+"app", DOCPROC+"data/worst.sd")
    start

    puts "YES; WE GOT HERE!!"

    # cluster1
    feed_and_compare("A docproc for all clusters", "cluster1/container.0/chain.common storage")
    feed_and_compare("Docproc only for cluster1", "cluster1/container.0/chain.cluster1 storage")

    # cluster2
    feed_and_compare("A docproc for all clusters", "cluster2/container.0/chain.common storage")
    feed_and_compare("Docproc only for cluster2", "cluster2/container.0/chain.cluster2 storage")
  end

  def feed_and_compare(expected, route="default", hitField="title")
    for i in 0..65 do
      doc1 = Document.new("worst", "id:worst:worst::1234").
        add_field("title", "jalla jalla")

      vespa.document_api_v1.put(doc1, :route => route)
      doc1 = vespa.document_api_v1.get("id:worst:worst::1234")
      actual = doc1.fields["title"]

      if expected != actual
        puts "expected: " + expected
        puts "actual: " + actual
      else
        puts "Got actual = #{actual} on attempt no. #{i}"
        break
      end
      sleep 1
    end
    assert_equal(expected, actual)
  end

def teardown
    stop
  end

end
