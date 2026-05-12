# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class DocumentIdAttributeTest < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
    @schema_dir = selfdir + "schemas/"
    @doc = Document.new("id:storage_test:test:n=1234:1").add_field("some_field", 42)
    @dms_filename = "[documentmetastore].dat"
    @dms_docid_filename = "[documentmetastore].docids.dat"
    @dms_docid_file_size = 0x1000 + 4 + 29 # Header + bytes for length of string + bytes for actual string
  end

  def deploy_with(document_id_setting)
    puts "# Deploying with document-id setting '#{document_id_setting}'"
    system("cp #{@schema_dir}test.#{document_id_setting}.sd #{dirs.tmpdir}test.sd")
    deploy_app(SearchApp.new.sd(dirs.tmpdir + "test.sd"))
  end

  def redeploy_with(document_id_setting)
    puts "# Re-deploying with document-id setting '#{document_id_setting}'"
    system("cp #{@schema_dir}test.#{document_id_setting}.sd #{dirs.tmpdir}test.sd")
    deploy_output = redeploy(SearchApp.new.sd(dirs.tmpdir + "test.sd"))
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))
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

  def flushed_file_exists(directory, snapshot_num, filename, docname = "test")
    path = "#{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/n0/documents/#{docname}/0.ready/"
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

  def assert_metastore_file_does_exist(snapshot_num, docname = "test")
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_filename, docname)
    assert(exists, "Metastore docid file '#{@dms_filename}' does not exist")
  end

  def assert_metastore_docid_file_does_not_exist(snapshot_num, docname = "test")
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_docid_filename, docname)
    assert(!exists, "Metastore docid file '#{@dms_docid_filename}' exists")
  end

  def assert_metastore_docid_file_exists(snapshot_num, docname = "test")
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_docid_filename, docname)
    assert(exists, "Metastore docid file '#{@dms_docid_filename}' does not exist")
  end

  def assert_metastore_docid_file_of_size_exists(snapshot_num, expected_size, docname = "test")
    exists, size = flushed_file_exists("documentmetastore", snapshot_num, @dms_docid_filename, docname)
    assert(exists, "Metastore docid file '#{@dms_docid_filename}' does not exist")
    assert_equal(expected_size, size, "Metastore docid file size is incorrect")
  end

  def test_populating_and_visiting_docids
    set_description("Test that docids in the metastore are populated and can be visited")
    deploy_with "attribute"
    start

    feed
    assert_visiting_docids_works

    # To make sure that the document ids in the metastore are actually populated,
    # we flush and check that they are written to a file.
    flush
    assert_metastore_docid_file_of_size_exists(4, @dms_docid_file_size)

    # Let's make sure that visiting still works after loading the document ids from the file
    restart_proton("test", 1, skip_trigger_flush: true) # Already flushed
    assert_visiting_docids_works
  end

  def test_no_docids_by_default
    set_description("Test that docids in the metastore are not populated by default")
    deploy_with "default"
    start

    feed
    assert_visiting_docids_works

    # Make sure that the regular metastore file exists and that the docid file does not exist.
    flush
    assert_metastore_file_does_exist(4)
    assert_metastore_docid_file_does_not_exist(4)
  end

  def test_populate_docids_of_existing_documents_with_early_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy_with "fromdisk"
    start

    feed
    assert_visiting_docids_works

    flush
    redeploy_with "attribute"

    # No restart yet! Let's make sure that visiting still works.
    assert_visiting_docids_works

    # The docstore validation after the restart will automatically populate the doc ids.
    puts "# Restarting Proton (without flushing)"
    restart_proton("test", 1, skip_trigger_flush: true)

    # After the docstore validation, flushing should produce a file now.
    flush
    assert_metastore_docid_file_of_size_exists(6, @dms_docid_file_size)
  end

  def test_populate_docids_of_existing_documents_with_late_flush
    set_description("Test that docids in the metastore are populated for existing documents when activating storing of document ids at a later point")
    deploy_with "fromdisk"
    start

    feed
    assert_visiting_docids_works

    redeploy_with "attribute"

    # No restart yet! Let's make sure that visiting still works.
    assert_visiting_docids_works

    # Flushing at this point should still cause the document ids to be written to a file when flushing after the restart.
    # That is, this test case tests that populating the docids internally as part of the docstore validation after the restart
    # leads to an increase in the serial number, which causes the next flush to actually write the files.
    puts "# Restarting Proton (with flushing)"
    restart_proton("test", 1, skip_trigger_flush: false)

    # Let's make sure that visiting works after population the doc ids through the docstore validation.
    assert_visiting_docids_works

    # After the docstore validation, flushing should produce a file now.
    flush
    assert_metastore_docid_file_of_size_exists(6, @dms_docid_file_size)
  end

  def test_multiple_schemas
    set_description("Test that the document-id setting works on a per-schema basis")
    deploy_app(SearchApp.new.sd(@schema_dir + "foo.sd").sd(@schema_dir + "bar.sd"))
    start

    vespa.document_api_v1.put(Document.new("id:foo:foo::1").add_field("some_field", 42))
    wait_for_hitcount("sddocname:foo&nocache", 1, 60)
    vespa.document_api_v1.put(Document.new("id:bar:bar::1").add_field("some_field", 43))
    wait_for_hitcount("sddocname:bar&nocache", 1, 60)

    flush
    assert_metastore_file_does_exist(4, "foo")
    assert_metastore_docid_file_exists(4, "foo")
    assert_metastore_file_does_exist(4, "bar")
    assert_metastore_docid_file_does_not_exist(4, "bar")
  end

end
