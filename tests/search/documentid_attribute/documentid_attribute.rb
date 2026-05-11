# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

def get_searchnode
  vespa.search["search"].first
end

class DocIdsInMemoryTest < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
    @doc1 = Document.new("id:storage_test:test:n=1234:1").add_field("some_field", 42)
    @docid_file_size = 0x1000 + 4 + 29 # Header + bytes for length of string + bytes for actual string
  end

  def deploy_fromdisk
    puts "# Deploying with document-id: from-disk"
    system("cp #{selfdir}test.fromdisk.sd #{dirs.tmpdir}test.sd")
    deploy_app(SearchApp.new.sd(dirs.tmpdir + "test.sd"))
  end

  def deploy_attribute
    puts "# Deploying with document-id: attribute"
    system("cp #{selfdir}test.attribute.sd #{dirs.tmpdir}test.sd")
    deploy_app(SearchApp.new.sd(dirs.tmpdir + "test.sd"))
  end

  def feed_and_assert_visiting_docids()
    puts "# Feeding document"
    vespa.document_api_v1.put(@doc1)

    puts "# Vising docids"
    result = vespa.adminserver.execute("vespa-visit --fieldset \"[id]\"")
    assert(result =~ /id:storage_test:test:n=1234:1/)
  end

  def flush_and_assert_flushed_metastore_docids(snapshot_num)
    puts "# Checking if flushing creates metastore docid file"
    @searchnode.trigger_flush

    dms_path = "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/n0/documents/test/0.ready/documentmetastore/"
    filename = "#{dms_path}snapshot-#{snapshot_num}/[documentmetastore].docids.dat"
    result = nil
    30.times do
      puts "Checking if metastore docid file '#{filename}' exists..."
      result = vespa.adminserver.remote_eval("File.exist?(\"#{filename}\")")
      if result == true
        size = vespa.adminserver.remote_eval("File.size(\"#{filename}\")")
        puts "Size of docid file is #{size}"
        assert_equal(@docid_file_size, size)
        break
      end
      sleep 1
    end
    assert_equal(true, result, "Metastore docid file '#{filename}' does not exist")
  end

  def test_populate_docids
    set_description("Test that docids in the metastore are populated when adding a document")
    deploy_attribute
    @searchnode = get_searchnode
    start

    feed_and_assert_visiting_docids

    flush_and_assert_flushed_metastore_docids(4)
  end

  def test_populate_docids_of_existing_documents_with_early_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy_fromdisk
    @searchnode = get_searchnode
    start

    feed_and_assert_visiting_docids

    puts "# Flushing"
    @searchnode.trigger_flush

    deploy_attribute

    puts "# Restarting Proton (without flushing)"
    restart_proton("test", 1, skip_trigger_flush: true)

    flush_and_assert_flushed_metastore_docids(6)
  end

  def test_populate_docids_of_existing_documents_with_late_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy_fromdisk
    @searchnode = get_searchnode
    start

    feed_and_assert_visiting_docids

    deploy_attribute

    # Flushing at this point should still cause the document ids to be written to a field when flushing after the restart.
    # That is, this test case tests that populating the docids internally leads to an increase in the serial number,
    # which causes the next flush to actually write the files.
    puts "# Restarting Proton (with flushing)"
    restart_proton("test", 1, skip_trigger_flush: false)

    flush_and_assert_flushed_metastore_docids(6)
  end

end
