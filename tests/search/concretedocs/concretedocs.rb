# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ConcreteDocs < SearchTest

  def setup
      set_owner("musum")
  end

  def test_concrete_docs
    add_bundle_dir(File.expand_path(selfdir + "/concretedocs2"), "concretedocs2")
    add_bundle_dir(File.expand_path(selfdir + "/concretedocs"), "concretedocs")
    # TODO: use app generator once <container> tag is done
    deploy(selfdir+"app", [ selfdir+"concretedocs/vehicle.sd", selfdir+"concretedocs/ship.sd", selfdir+"concretedocs2/disease.sd" ])
    #deploy_app(SearchApp.new.sd(selfdir+"concretedocs/vehicle.sd").
    #             docproc(DocProcCluster.new.
    #               chain(DocProcChain.new.docproc("concretedocs.ConcreteDocDocProc", "concretedocs"))))
    start
    feed_and_wait_for_docs("vehicle", 2, :file => selfdir+"vehicle.xml")
    feed_and_wait_for_docs("disease", 2, :file => selfdir+"disease.xml")

    # Check docs in index
    assert_hitcount("query=year:2013", 2)
    assert_hitcount("query=symptom:Paralysis", 2)

    # Check docs with GET
    doc = vespa.document_api_v1.get("id:vehicle:vehicle::0")
    location = doc.fields["location"]
    assert(location["x"] == 2)
    assert(location["y"] == 3)
    assert(doc.fields["year"] == 2013)
    assert(doc.fields["reg"] == "FOO 1234")

    doc = vespa.document_api_v1.get("id:vehicle:vehicle::1")
    location = doc.fields["location"]
    assert(location["x"] == 2)
    assert(location["y"] == 3)
    assert(doc.fields["year"] == 2013)
    assert(doc.fields["reg"] == "BAR 5678")

    doc = vespa.document_api_v1.get("id:disease:disease::0")
    assert(doc.fields["symptom"] == "Paralysis")

    doc = vespa.document_api_v1.get("id:disease:disease::1")
    assert(doc.fields["symptom"] == "Paralysis")

  end

  def teardown
    stop
  end

end

