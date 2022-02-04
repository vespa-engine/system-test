# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'

class VespaGet < MultiProviderStorageTest

  def setup
    set_owner("vekterli")
  end

  def run_vespaget(args, storage_cluster = "storage")
    vespa.storage[storage_cluster].storage["0"].
      execute("vespa-get " + args);
  end
  
  def test_vespaget_standard_clustername
    deploy_app(default_app)
    start

    doc = Document.new("music", "id:storage_test:music:n=1234:document1").
      add_field("title", "title1")
    vespa.document_api_v1.put(doc)
    doc = Document.new("music", "id:storage_test:music:n=1234:document2").
      add_field("title", "title2").
      add_field("band", "foo").
      add_field("body", "bar")
    vespa.document_api_v1.put(doc)

    output = run_vespaget("id:storage_test:music:n=1234:document1");
    assert_match("title1", output);

    output = run_vespaget("id:storage_test:music:n=1234:document2");
    assert_match("title2", output);

    output = run_vespaget("--printids id:storage_test:music:n=1234:document2");
    assert_no_match("title2", output);
    assert_no_match("foo", output);
    assert_no_match("bar", output);

    output = run_vespaget("--fieldset music:title,body id:storage_test:music:n=1234:document2");
    assert_match("title2", output);
    assert_match("bar", output);
    assert_no_match("foo", output);

    output = run_vespaget("id:storage_test:music:n=1234:nonexist || true");
    assert_match("not found", output);

    output = run_vespaget("--trace 9 id:storage_test:music:n=1234:document1");
    assert_match("\<trace\>", output);
  end

  def test_vespaget_nonstandard_clustername
    sd_file = VDS + "/schemas/music.sd"
    deploy_app(StorageApp.new.
               enable_document_api(FeederOptions.new.timeout(40)).
               default_cluster("dummy").sd(sd_file).
               transition_time(0))
    start

    doc = Document.new("music", "id:storage_test:music:n=1234:document1").
      add_field("title", "title1")
    vespa.document_api_v1.put(doc)
    doc = Document.new("music", "id:storage_test:music:n=1234:document2").
      add_field("title", "title2")
    vespa.document_api_v1.put(doc)

    output = run_vespaget("id:storage_test:music:n=1234:document1", "dummy");
    assert_match("title1", output);

    output = run_vespaget("id:storage_test:music:n=1234:document2", "dummy");
    assert_match("title2", output);

    output = run_vespaget("id:storage_test:music:n=1234:nonexist || true", "dummy");
    assert_match("not found", output);

    output = run_vespaget("--cluster dummy id:storage_test:music:n=1234:document1", "dummy");
    assert_match("title1", output);
  end

  def teardown
    stop
  end
end

