# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Initialization < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
  end

  def test_initialization
    set_description("Verify contents of /state/v1/initialization after startup")
    deploy_app(SearchApp.new.sd(selfdir + "initialization.sd"))
    @searchnode = get_searchnode
    start

    dbs = {
      "initialization" => {
        "loaded" => ["int_field1", "string_field1", "string_field3", "tensor_field"] ,
        "loading" => [],
        "reprocessing" => [],
        "queued" => []
      }
    }

    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)

    # Feed a document
    doc = Document.new("id:initialization:initialization::0")
                  .add_field("int_field1", "1")
                  .add_field("string_field1", "foo")
                  .add_field("string_field2", "bar")
                  .add_field("string_field3", "baz")
                  .add_field("tensor_field", [1, 2, 3])
    vespa.document_api_v1.put(doc)

    # Restart without flushing
    restart_vespa_and_wait
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)

    # Flush and restart Vespa
    @searchnode.trigger_flush
    restart_vespa_and_wait
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)
  end

  def test_multiple_schemas
    set_description("Verify contents of /state/v1/initialization after startup while using multiple schemas")
    deploy(selfdir + "multiple_schemas/")
    @searchnode = get_searchnode
    start

    dbs = {
      "foo" => {
        "loaded" => ["int_foo1", "string_foo1", "string_foo3", "tensor_foo"] ,
        "loading" => [],
        "reprocessing" => [],
        "queued" => []
      },
      "bar" => {
        "loaded" => ["int_bar1", "string_bar1", "string_bar3", "tensor_bar"] ,
        "loading" => [],
        "reprocessing" => [],
        "queued" => []
      }
    }

    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)

    # Feed two documents
    foo = Document.new("id:foo:foo::0")
                  .add_field("int_foo1", "1")
                  .add_field("string_foo1", "foo")
                  .add_field("string_foo2", "bar")
                  .add_field("string_foo3", "baz")
                  .add_field("tensor_foo", [1, 2, 3])
    vespa.document_api_v1.put(foo)

    bar = Document.new("id:bar:bar::0")
                  .add_field("int_bar1", "1")
                  .add_field("string_bar1", "foo")
                  .add_field("string_bar2", "bar")
                  .add_field("string_bar3", "baz")
                  .add_field("tensor_bar", [1, 2, 3])
    vespa.document_api_v1.put(bar)

    # Flush and restart Vespa
    @searchnode.trigger_flush
    restart_vespa_and_wait
    puts "Waiting for 1 hit per schema"
    wait_for_atleast_hitcount("query=sddocname:foo", 1)
    wait_for_atleast_hitcount("query=sddocname:bar", 1)
    puts "Waited for 1 hit per schema"

    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)
  end

  def test_reprocessing
    set_description("Verify contents of /state/v1/initialization while reindexing an HNSW index")

    # First, we use a schema where tensor_field is not an index
    testdir = selfdir + "reprocessing/"
    system("cp #{testdir}reprocessing.0.sd #{dirs.tmpdir}reprocessing.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "reprocessing.sd")
    deploy_app(app)

    @container = get_container
    @searchnode = get_searchnode
    # Compile document generator
    @tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -g -O3 -o #{@tmp_bin_dir}/docs #{selfdir}docs.cpp")
    start

    feed_documents(50000, 2048)

    puts "Redeploying with HNSW index"
    system("cp #{testdir}reprocessing.1.sd #{dirs.tmpdir}reprocessing.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "reprocessing.sd")
    deploy_output = redeploy(app)

    puts "Waiting for config to settle"
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))

    restart_vespa

    puts "Waiting for a few seconds"
    sleep 5

    dbs = {
      "reprocessing" => {
        "loaded" => ["int_field", "string_field"],
        "loading" => [],
        "reprocessing" => ["tensor_field"],
        "queued" => []
      }
    }

     # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, dbs)
  end

  def feed_documents(num_documents, num_dimensions)
    puts "Feeding documents"
    @container.execute("#{@tmp_bin_dir}/docs #{num_documents} #{num_dimensions} | vespa-feed-perf")

    puts "Waiting for #{num_documents} hits"
    wait_for_atleast_hitcount("query=sddocname:reprocessing", num_documents)
    puts "Waited for #{num_documents} hits"
  end

  def restart_vespa
    puts "# Stopping Vespa"
    vespa.stop_base
    vespa.adminserver.stop_configserver(:keep_everything => true)
    puts "# Starting Vespa"
    vespa.adminserver.start_configserver
    vespa.adminserver.ping_configserver
    vespa.start_base
  end

  def restart_vespa_and_wait
    restart_vespa

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"
  end

  def assert_status(initialization, expected_dbs)
    # Checking if any of the expected dbs is still initializing
    expected_ready = true
    expected_dbs.each do |expected_name, expected_attribute_names|
      expected_ready = (expected_ready and expected_attribute_names["reprocessing"].length == 0)
    end

    # Overall state
    state = initialization["state"]
    assert_not_nil state
    assert_equal(state, expected_ready ? "ready" : "initializing")

    # Timestamps
    start_time = initialization["start_time"]
    assert_not_nil start_time
    assert start_time.to_f > 0

    current_time = initialization["current_time"]
    assert_not_nil current_time
    assert current_time.to_f >= start_time.to_f

    if expected_ready
      end_time = initialization["end_time"]
      assert_not_nil end_time
      assert end_time.to_f >= start_time.to_f
      assert end_time.to_f <= current_time.to_f
    end

    dbs = initialization["dbs"]
    assert_not_nil dbs
    assert_equal(dbs.length, expected_dbs.length)

    expected_dbs.each do |expected_name, expected_attribute_names|
      assert_db(dbs, current_time, expected_name, expected_attribute_names)
    end
  end

  def assert_db(dbs, current_time, expected_name, expected_attribute_names)
    # Get status of db "name"
    name_db = nil
    dbs.each do |db|
      assert_not_nil db["name"]
      if db["name"] == expected_name
        name_db = db
      end
    end

    assert_not_nil name_db
    assert_specific_db(name_db, current_time, expected_name, expected_attribute_names)
  end

  def assert_specific_db(db, current_time, expected_name, expected_attribute_names)
    expected_ready = expected_attribute_names["reprocessing"].length == 0

    # Name
    db_name = db["name"]
    assert_not_nil db_name
    assert_equal(db_name, expected_name)

    # State
    db_state = db["state"]
    assert_not_nil db_state
    assert_equal(db_state, expected_ready ? "ready" : "load")

    # Replay progress
    if expected_ready
      db_replay_progress = db["replay_progress"]
      assert_not_nil db_replay_progress
      assert((db_replay_progress.to_f - 1.0).abs < 0.001)
    end

    # Timestamps
    db_start_time = db["start_time"]
    assert_not_nil db_start_time
    assert(db_start_time.to_f > 0)

    if expected_ready
      db_replay_start_time = db["replay_start_time"]
      assert_not_nil db_replay_start_time
      assert(db_replay_start_time.to_f >= db_start_time.to_f)

      db_replay_end_time = db["replay_end_time"]
      assert_not_nil db_replay_end_time
      assert(db_replay_end_time.to_f >= db_replay_start_time.to_f)

      db_end_time = db["end_time"]
      assert_not_nil db_end_time
      assert(db_end_time.to_f >= db_replay_end_time.to_f)
      assert(current_time.to_f >= db_end_time.to_f)
    end

    # Loaded attributes
    db_loaded_attributes = db["ready_subdb"]["loaded_attributes"]
    assert_equal(db_loaded_attributes.length, expected_attribute_names["loaded"].length)
    expected_attribute_names["loaded"].each do |attribute_name|
      assert_attribute_loaded(db_loaded_attributes, current_time, attribute_name)
    end

    # Loading attributes
    db_loading_attributes = db["ready_subdb"]["loading_attributes"]
    assert_equal(db_loading_attributes.length, expected_attribute_names["loading"].length + expected_attribute_names["reprocessing"].length)
    expected_attribute_names["loading"].each do |attribute_name|
      assert_attribute_loading(db_loaded_attributes, current_time, attribute_name)
    end
    expected_attribute_names["reprocessing"].each do |attribute_name|
      assert_attribute_reprocessing(db_loading_attributes, current_time, attribute_name)
    end

    db_queued_attributes = db["ready_subdb"]["queued_attributes"]
    assert_equal(db_queued_attributes.length, expected_attribute_names["queued"].length)
    expected_attribute_names["queued"].each do |attribute_name|
      assert_attribute_queued(db_queued_attributes, current_time, attribute_name)
    end
  end

  def assert_attribute_loaded(loaded_attributes, current_time, expected_name)
    name_attribute = nil
    loaded_attributes.each do |attribute|
      assert_not_nil attribute["name"]
      if attribute["name"] == expected_name
        name_attribute = attribute
      end
    end

    assert_not_nil name_attribute
    assert_specific_attribute_loaded(name_attribute, current_time, expected_name)
  end

  def assert_specific_attribute_loaded(attribute, current_time, expected_name)
    # Name
    attribute_name = attribute["name"]
    assert_equal(attribute_name, expected_name)

    # Status
    attribute_status = attribute["status"]
    assert_not_nil attribute_status
    assert_equal(attribute_status, "loaded")

    # Timestamps
    attribute_loading_started = attribute["loading_started"]
    assert_not_nil attribute_loading_started
    assert(attribute_loading_started.to_f > 0)

    attribute_loading_finished = attribute["loading_finished"]
    assert_not_nil attribute_loading_finished
    assert attribute_loading_finished.to_f >= attribute_loading_started.to_f
    assert current_time.to_f >= attribute_loading_finished.to_f
  end

  def assert_attribute_reprocessing(loaded_attributes, current_time, expected_name)
    name_attribute = nil
    loaded_attributes.each do |attribute|
      assert_not_nil attribute["name"]
      if attribute["name"] == expected_name
        name_attribute = attribute
      end
    end

    assert_not_nil name_attribute
    assert_specific_attribute_reprocessing(name_attribute, current_time, expected_name)
  end

  def assert_specific_attribute_reprocessing(attribute, current_time, expected_name)
    # Name
    attribute_name = attribute["name"]
    assert_equal(attribute_name, expected_name)

    # Status
    attribute_status = attribute["status"]
    assert_not_nil attribute_status
    assert_equal(attribute_status, "reprocessing")

    attribute_reprocessing_progress = attribute["reprocessing_progress"]
    assert_not_nil attribute_reprocessing_progress
    assert(attribute_reprocessing_progress.to_f > 0.0)
    assert(attribute_reprocessing_progress.to_f < 100.0)

    # Timestamps
    attribute_loading_started = attribute["loading_started"]
    assert_not_nil attribute_loading_started
    assert(attribute_loading_started.to_f > 0)
  end

  def assert_attribute_loading(loaded_attributes, current_time, expected_name)
    name_attribute = nil
    loaded_attributes.each do |attribute|
      assert_not_nil attribute["name"]
      if attribute["name"] == expected_name
        name_attribute = attribute
      end
    end

    assert_not_nil name_attribute
    assert_specific_attribute_loading(name_attribute, current_time, expected_name)
  end

  def assert_specific_attribute_loading(attribute, current_time, expected_name)
    # Name
    attribute_name = attribute["name"]
    assert_equal(attribute_name, expected_name)

    # Status
    attribute_status = attribute["status"]
    assert_not_nil attribute_status
    assert_equal(attribute_status, "load")

    # Timestamps
    attribute_loading_started = attribute["loading_started"]
    assert_not_nil attribute_loading_started
    assert(attribute_loading_started.to_f > 0)
  end

  def assert_attribute_queued(loaded_attributes, current_time, expected_name)
    name_attribute = nil
    loaded_attributes.each do |attribute|
      assert_not_nil attribute["name"]
      if attribute["name"] == expected_name
        name_attribute = attribute
      end
    end

    assert_not_nil name_attribute
    assert_specific_attribute_queued(name_attribute, current_time, expected_name)
  end

  def assert_specific_attribute_queued(attribute, current_time, expected_name)
    # Name
    attribute_name = attribute["name"]
    assert_equal(attribute_name, expected_name)

    # Status
    attribute_status = attribute["status"]
    assert_not_nil attribute_status
    assert_equal(attribute_status, "queued")
  end

  def get_container
    vespa.qrserver["0"] or vespa.container.values.first
  end

  def get_searchnode
    searchnode_array = @vespa.services.select {|service| service.servicetype == "searchnode"}
    assert_equal(1, searchnode_array.length)
    searchnode_array[0]
  end

  def teardown
    stop
  end

end
