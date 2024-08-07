# Copyright Vespa.ai. All rights reserved.

require 'vds_test'

class Reprocessing < VdsTest

  def can_share_configservers?
    false
  end

  def setup
    set_owner("vekterli")
    @valgrind = false

    add_bundle("#{selfdir}/NullDocProc.java")
    add_bundle("#{selfdir}/TestDocProc.java")
    add_bundle("#{selfdir}/SkipDocProc.java")
    deploy(selfdir + "setup-docproc")

    start
  end

  def test_reprocessing
    doc = Document.new("music", "id:storage_test:music:n=1234:0").
      add_field("year", 1).
      add_field("bodyfield", "foo")
    vespa.document_api_v1.put(doc)

    # Get the document we just stored.
    doc2 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")
    assert_equal(doc, doc2)

    vespa.storage["storage"].storage["0"].execute("vespa-visit --datahandler \"reprocess/chain.reprocess-chain storage\"")

    doc3 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")

    assert_equal(2, doc3.fields["year"].to_i)

    vespa.storage["storage"].storage["0"].execute("vespa-visit --datahandler \"reprocess/chain.reprocess-chain storage\"")

    doc3 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")

    assert_equal(3, doc3.fields["year"].to_i)
    assert_equal("foo", doc3.fields["bodyfield"].to_s)

    # Check that docproc that skips all documents does not send empty multioperationmessages (bug 2591369)
    vespa.storage["storage"].storage["0"].execute("vespa-visit --datahandler \"skip/chain.skip-chain storage\"")

    # Deploy config without 'bodyfield'
    deploy_output = deploy(selfdir + "setup2-docproc")
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_reconfig(get_generation(deploy_output).to_i, 600, true)

    # Reprocess again, unknown fields should now be skipped and essentially disappear
    vespa.storage["storage"].storage["0"].execute("vespa-visit --datahandler \"reprocess/chain.reprocess-chain storage\"")

    doc4 = vespa.document_api_v1.get("id:storage_test:music:n=1234:0")
    puts doc4.inspect
    assert_equal(nil, doc4.fields["bodyfield"])
  end

  def teardown
    stop
  end
end

