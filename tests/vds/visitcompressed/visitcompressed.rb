# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'

class VisitCompressedDocumentsTest < MultiProviderStorageTest

  def nightly?
    true
  end

  def setup
    set_owner("vekterli")
  end

  def teardown
    stop
  end

  def do_visit_with_compressed_documents
    # Assuming visiting will abort and assert if any of this fails
    # Although visiting is generally not ordered in a deterministic fashion,
    # all docs are for the same user, so only one bucket to visit
    puts "Testing full document visiting"
    java_output = vespa.storage["storage"].storage["0"].execute("vespa-visit --xmloutput")

    puts "Testing headers only"
    java_output = vespa.storage["storage"].storage["0"].execute("vespa-visit -i")
  end

  def test_visit_with_compressed_full_documents
    deploy_app(default_app_no_sd.sd(selfdir + 'compressed-fulldoc/music.sd'))
    start
    feedfile(selfdir + 'feed.xml')
    do_visit_with_compressed_documents
  end

end
