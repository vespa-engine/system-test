# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class DocIdsInMemoryTest < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
    @doc = Document.new("id:storage_test:test:n=1234:1").add_field("some_field", 42)
    @dms_filename = "[documentmetastore].dat"
    @dms_docid_filename = "[documentmetastore].docids.dat"
    @dms_docid_file_size = 0x1000 + 4 + 29 # Header + bytes for length of string + bytes for actual string
  end

  def deploy(document_id_setting)
    puts "# Deploying with document-id setting '#{document_id_setting}'"
    system("cp #{selfdir}test.#{document_id_setting}.sd #{dirs.tmpdir}test.sd")
    deploy_app(SearchApp.new.sd(dirs.tmpdir + "test.sd"))
  end

  def feed
    puts "# Feeding document"
    vespa.document_api_v1.put(@doc)
    wait_for_hitcount("sddocname:test&nocache", 1, 60)
  end

  def assert_visiting_docids_works
    puts "# Vising docids"
    result = vespa.adminserver.execute("vespa-visit --fieldset \"[id]\"")
    assert(result =~ /id:storage_test:test:n=1234:1/)
  end

  def flush
    puts "# Flushing"
    vespa.search["search"].first.trigger_flush
  end

  def flushed_file_exists(directory, snapshot_num, filename)
    path = "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/n0/documents/test/0.ready/"
    sub_path = "#{directory}/snapshot-#{snapshot_num}/#{filename}"
    puts "# Checking if '#{sub_path}' exists in '#{path}'"
    full_path = path + sub_path
    exists = false
    size = 0
    30.times do
      puts "Checking if '#{filename}' exists..."
      exists = vespa.adminserver.remote_eval("File.exist?(\"#{full_path}\")")
      if exists
        size = vespa.adminserver.remote_eval("File.size(\"#{full_path}\")")
        puts "Size of docid file is #{size}"
        break
      end
      sleep 1
    end

    return exists, size
  end

  def assert_metastore_file_does_exist(snapshot_num)
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_filename)
    assert(exists, "Metastore docid file '#{@dms_filename}' does not exist")
  end

  def assert_metastore_docid_file_does_not_exist(snapshot_num)
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_docid_filename)
    assert(!exists, "Metastore docid file '#{@dms_docid_filename}' exists")
  end

  def assert_metastore_docid_file_of_size_exists(snapshot_num, expected_size)
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_docid_filename)
    assert(exists, "Metastore docid file '#{@dms_docid_filename}' does not exist")
    assert_equal(expected_size, size, "Metastore docid file size is incorrect")
  end

  def test_no_docids_by_default
    set_description("Test that docids in the metastore are not populated by default")
    deploy "default"
    start

    feed
    assert_visiting_docids_works

    flush
    assert_metastore_file_does_exist(4)
    assert_metastore_docid_file_does_not_exist(4)
  end

  def test_populate_docids
    set_description("Test that docids in the metastore are populated when adding a document")
    deploy "attribute"
    start

    feed
    assert_visiting_docids_works

    flush
    assert_metastore_docid_file_of_size_exists(4, @dms_docid_file_size)
  end

  def test_visiting_after_loading_docid_file
    set_description("Test that visiting of docids still works after a document id file has been loaded")
    deploy "attribute"
    start

    feed
    assert_visiting_docids_works

    flush
    assert_metastore_docid_file_of_size_exists(4, @dms_docid_file_size)

    restart_proton("test", 1, skip_trigger_flush: true)
    assert_visiting_docids_works
  end

  def test_populate_docids_of_existing_documents_with_early_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy"fromdisk"
    start

    feed
    assert_visiting_docids_works

    flush
    deploy "attribute"

    puts "# Restarting Proton (without flushing)"
    restart_proton("test", 1, skip_trigger_flush: true)

    flush
    assert_metastore_docid_file_of_size_exists(6, @dms_docid_file_size)
  end

  def test_populate_docids_of_existing_documents_with_late_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy "fromdisk"
    start

    feed
    assert_visiting_docids_works

    deploy "attribute"

    # Flushing at this point should still cause the document ids to be written to a file when flushing after the restart.
    # That is, this test case tests that populating the docids internally as part of the docstore validation after the restart
    # leads to an increase in the serial number, which causes the next flush to actually write the files.
    puts "# Restarting Proton (with flushing)"
    restart_proton("test", 1, skip_trigger_flush: false)

    flush
    assert_metastore_docid_file_of_size_exists(6, @dms_docid_file_size)
  end

end
