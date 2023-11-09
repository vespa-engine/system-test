# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_multi_model_test'

class MultipleSearchDefs < VdsMultiModelTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app)
    set_expected_logged(/Document type .* not found/)
    start
  end

  def vespaget(documentname, params={})
    vespa.content_node("storage", 0).execute("vespa-get --noretry #{documentname}", params)
  end

  def test_twosearchdefs
    # music application is deployed => should fail to feed music2 documents but succeed in feeding music documents
    output = feedfile(selfdir+"music.xml")
    assert_no_match(/Must specify an existing document type/, output)

    output = feedfile(selfdir+"music2.xml", :exceptiononfailure => false, :stderr => true)
    assert_match(/Must specify an existing document type/, output)

    # Test vespaget
    output = vespaget("id:storage_test:music:n=1234:music1")
    assert_match(/id:storage_test:music:n=1234:music1/, output)
    output = vespaget("id:storage_test:music2:n=1234:music2", :exceptiononfailure => false, :stderr => true)
    assert_match(/Unknown bucket space mapping for document type 'music2'/, output)
    output = vespa.content_node("storage", 0).execute("vespa-visit --xmloutput")
    assert(/id:storage_test:music:n=1234:music1/, output)

    puts "1 **************************************************************"
    deploy_output = deploy_app(default_app("music2").validation_override("content-type-removal"))
    config_generation = get_generation(deploy_output).to_i
    wait_for_reconfig(config_generation)

    # music2 application is deployed => should fail to feed music documents but succeed in feeding music2 documents
    output = feedfile(selfdir+"music.xml", :exceptiononfailure => false, :stderr => true)
    assert_match(/Must specify an existing document type/, output)

    output = feedfile(selfdir+"music2.xml")
    assert_no_match(/Must specify an existing document type/, output)

    # Test vespaget
    output = vespaget("id:storage_test:music:n=1234:music1", :exceptiononfailure => false, :stderr => true)
    assert_match(/Unknown bucket space mapping for document type 'music'/, output)
    output = vespaget("id:storage_test:music2:n=1234:music2")
    assert_no_match(/ReturnCode/, output)
    output = vespa.content_node("storage", 0).execute("vespa-visit --xmloutput || true")
    assert_no_match(/Document type music not found/, output)

    puts "2 **************************************************************"

    deploy_output = deploy_app(default_app.validation_override("content-type-removal"))
    config_generation = get_generation(deploy_output).to_i
    wait_for_reconfig(config_generation)

    # music application is deployed => should fail to feed music2 documents but succeed in feeding music documents
    output = feedfile(selfdir+"music.xml", :retries => 3)
    assert_no_match(/Must specify an existing document type/, output)

    output = feedfile(selfdir+"music2.xml", :exceptiononfailure => false, :stderr => true)
    assert_match(/Must specify an existing document type/, output)

    # Test vespaget
    output = vespaget("id:storage_test:music:n=1234:music1")
    assert_no_match(/ReturnCode/, output)
    output = vespaget("id:storage_test:music2:n=1234:music2", :exceptiononfailure => false, :stderr => true)
    assert_match(/Unknown bucket space mapping for document type 'music2'/, output)
    output = vespa.content_node("storage", 0).execute("vespa-visit --xmloutput || true")
    assert_no_match(/Document type music2 not found/, output)

    puts "3 **************************************************************"

    # Now deploy application with both document types => put/get should work for both
    deploy_output = deploy_app(default_app.sd(VDS + "/schemas/music2.sd").validation_override("content-type-removal"))
    config_generation = get_generation(deploy_output).to_i
    wait_for_reconfig(config_generation)

    # Test vespaget
    output = vespaget("id:storage_test:music:n=1234:music1")
    assert_no_match(/ReturnCode/, output)
    output = vespaget("id:storage_test:music2:n=1234:music2")
    assert_no_match(/ReturnCode/, output)

    output = feedfile(selfdir+"music.xml", :retries => 3)
    assert_no_match(/Must specify an existing document type/, output)

    output = feedfile(selfdir+"music2.xml", :retries => 3)
    assert_no_match(/Must specify an existing document type/, output)

    output = vespa.content_node("storage", 0).execute("vespa-visit --xmloutput || true")
    assert_match(/id:storage_test:music:n=1234:music1/, output)
    assert_match(/id:storage_test:music2:n=1234:music2/, output)
  end

  def teardown
    stop
  end
end

