# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Initialization < IndexedStreamingSearchTest

  NUM_DOCUMENTS = 50000

  def setup
    set_owner("boeker")
    @valgrind = false
    @valgrind_opt = nil
  end

  def self.final_test_methods
    ['test_replay',
     'test_reprocessing']
  end

  def test_initialization
    set_description("Verify contents of /state/v1/initialization after startup")
    deploy_app(SearchApp.new.sd(selfdir + "initialization/initialization.sd"))
    @searchnode = get_searchnode
    start

    loaded = ["int_field1", "string_field1", "string_field3", "tensor_field"]
    if is_streaming
      loaded = []
    end

    expected = {
      "state" => "ready",
      "dbs" => {
        "initialization" => {
          "state" => "online",
          "attributes" => {
            "loaded" => loaded,
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status(expected)

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

    assert_v1_status(expected)

    # Flush and restart Vespa
    @searchnode.trigger_flush
    restart_vespa_and_wait
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    assert_v1_status(expected)
  end

  def test_multiple_schemas
    set_description("Verify contents of /state/v1/initialization after startup while using multiple schemas")
    deploy_app(SearchApp.new.sd(selfdir + "initialization/multiple_schemas/foo.sd")
                            .sd(selfdir + "initialization/multiple_schemas/bar.sd"))
    @searchnode = get_searchnode
    start

    fooLoaded = ["int_foo1", "string_foo1", "string_foo3", "tensor_foo"]
    barLoaded = ["int_bar1", "string_bar1", "string_bar3", "tensor_bar"]

    if is_streaming
      fooLoaded = []
      barLoaded = []
    end

    expected = {
      "state" => "ready",
      "dbs" => {
        "foo" => {
          "state" => "online",
          "attributes" => {
            "loaded" => fooLoaded,
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        },
        "bar" => {
          "state" => "online",
          "attributes" => {
            "loaded" => barLoaded,
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status(expected)

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

    assert_v1_status(expected)
  end

  def test_replay
    @params = { :search_type => "INDEXED" }
    set_description("Verify contents of /state/v1/initialization while replay")
    deploy_app(SearchApp.new.sd(selfdir + "initialization/replay/replay.sd").flush_on_shutdown(false))

    @container = get_container
    @searchnode = get_searchnode
    compile_document_generator
    start

    feed_and_wait("replay", NUM_DOCUMENTS, 2048)

    restart_vespa

    puts "Waiting for a few seconds until replay"
    wait_for_replay
    puts "Waiting for one more second"
    sleep 1

    expected = {
      "state" => "initializing",
      "dbs" => {
        "replay" => {
          "state" => "replay_transaction_log",
          "attributes" => {
            "loaded" => ["int_field", "string_field", "tensor_field"],
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status expected

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"

    expected = {
      "state" => "ready",
      "dbs" => {
        "replay" => {
          "state" => "online",
          "attributes" => {
            "loaded" => ["int_field", "string_field", "tensor_field"],
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status expected
  end

  def test_reprocessing
    @params = { :search_type => "INDEXED" }
    set_description("Verify contents of /state/v1/initialization while reindexing an HNSW index")

    # First, we use a schema where tensor_field is not an index
    testdir = selfdir + "initialization/reprocessing/"
    system("cp #{testdir}reprocessing.0.sd #{dirs.tmpdir}reprocessing.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "reprocessing.sd")
    deploy_app(app)

    @container = get_container
    @searchnode = get_searchnode
    compile_document_generator
    start

    feed_and_wait("reprocessing", NUM_DOCUMENTS, 2048)

    puts "Redeploying with HNSW index"
    system("cp #{testdir}reprocessing.1.sd #{dirs.tmpdir}reprocessing.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "reprocessing.sd")
    deploy_output = redeploy(app)

    puts "Waiting for config to settle"
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))

    @searchnode.trigger_flush # Explicitly flush since we only restart proton
    restart_vespa

    puts "Waiting for a few seconds until reprocessing"
    wait_for_reprocessing
    puts "Waiting for one more second"
    sleep 1

    expected = {
      "state" => "initializing",
      "dbs" => {
        "reprocessing" => {
          "state" => "load",
          "attributes" => {
            "loaded" => ["int_field", "string_field"],
            "loading" => [],
            "reprocessing" => ["tensor_field"],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status expected

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"

    expected = {
      "state" => "ready",
      "dbs" => {
        "reprocessing" => {
          "state" => "online",
          "attributes" => {
            "loaded" => ["int_field", "string_field", "tensor_field"],
            "loading" => [],
            "reprocessing" => [],
            "queued" => []
          }
        }
      }
    }

    assert_v1_status expected
  end

  def wait_for_replay
    60.times do
      initialization = @searchnode.get_state_v1("initialization")
      next if initialization.nil?

      dbs = initialization["dbs"]
      next if dbs.nil?

      dbs.each do |db|
        db_state = db["state"]
        next if db_state.nil?

        return if db_state == "replay_transaction_log"
      end

      puts "Waiting for a second before checking for replay again"
      sleep 1
    end
  end

  def wait_for_reprocessing
    60.times do
      initialization = @searchnode.get_state_v1("initialization")
      next if initialization.nil?

      dbs = initialization["dbs"]
      next if dbs.nil?

      dbs.each do |db|
        ready_subdb = db["ready_subdb"]
        next if ready_subdb.nil?

        loading_attributes = ready_subdb["loading_attributes"]
        next if loading_attributes.nil?

        loading_attributes.each do |loading_attribute|
          state = loading_attribute["state"]
          next if state.nil?

          return if state == "reprocessing"
        end
      end

      puts "Waiting for a second before checking for reprocessing again"
      sleep 1
    end
  end

  def wait_for_documents(name, num_documents)
    puts "Waiting for #{num_documents} hits"
    wait_for_atleast_hitcount("query=sddocname:#{name}", num_documents)
    puts "Waited for #{num_documents} hits"
  end

  def feed_and_wait(name, num_documents, num_dimensions)
    puts "Feeding documents"
    @container.execute("#{@tmp_bin_dir}/docs #{name} #{num_documents} #{num_dimensions} | vespa-feed-perf")
    wait_for_documents(name, num_documents)
  end

  def compile_document_generator
    @tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -g -O3 -o #{@tmp_bin_dir}/docs #{selfdir}initialization-data/docs.cpp")
  end

  def restart_vespa
    puts "# Stopping Proton"
    @searchnode.stop

    puts "# Starting Proton"
    @searchnode.start
  end

  def restart_vespa_and_wait
    restart_vespa

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"
  end


  def assert_v1_status(expected)
    # Verify that initialization status is as expected
    initialization = @searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_status(initialization, expected)
  end

  def assert_status(initialization, expected)
    # Overall state
    state = initialization["state"]
    assert_not_nil state
    assert_equal(expected["state"], state)

    # Timestamps
    start_time = initialization["start_time"]
    assert_not_nil start_time
    assert start_time.to_f > 0

    current_time = initialization["current_time"]
    assert_not_nil current_time
    assert current_time.to_f >= start_time.to_f

    if expected["state"]== "online"
      end_time = initialization["end_time"]
      assert_not_nil end_time
      assert end_time.to_f >= start_time.to_f
      assert end_time.to_f <= current_time.to_f
    end

    # Check DB counts
    expected_load = 0
    expected_replay = 0
    expected_online = 0
    expected["dbs"].each do |expected_name, expected_db|
      case expected_db["state"]
      when "load"
        expected_load += 1
      when "replay_transaction_log"
        expected_replay += 1
      else
        expected_online += 1
      end
    end

    num_load = initialization["load"]
    assert_not_nil num_load
    assert_equal(expected_load, num_load)

    num_replay = initialization["replay_transaction_log"]
    assert_not_nil num_replay
    assert_equal(expected_replay, num_replay)

    num_online = initialization["online"]
    assert_not_nil num_online
    assert_equal(expected_online, num_online)

    # Check individual DBs
    dbs = initialization["dbs"]
    assert_not_nil dbs
    assert_equal(expected["dbs"].length, dbs.length)

    expected["dbs"].each do |expected_name, expected_db|
      assert_db(dbs, current_time, expected_name, expected_db)
    end
  end

  def assert_db(dbs, current_time, expected_name, expected_db)
    # Get status of db "name"
    name_db = nil
    dbs.each do |db|
      assert_not_nil db["name"]
      if db["name"] == expected_name
        name_db = db
      end
    end

    assert_not_nil name_db
    assert_specific_db(name_db, current_time, expected_name, expected_db)
  end

  def assert_specific_db(db, current_time, expected_name, expected_db)
    # Name
    db_name = db["name"]
    assert_not_nil db_name
    assert_equal(expected_name, db_name)

    # State
    db_state = db["state"]
    assert_not_nil db_state
    assert_equal(expected_db["state"], db_state)

    # Replay progress
    if expected_db["stat"] == "replay_transaction_log"
      db_replay_progress = db["replay_progress"]
      assert_not_nil db_replay_progress
      assert((db_replay_progress.to_f - 1.0).abs < 0.001)
    end

    # Timestamps
    db_start_time = db["start_time"]
    assert_not_nil db_start_time
    assert(db_start_time.to_f > 0)

    db_replay_start_time = db["replay_start_time"]
    if expected_db["stat"] == "replay"
      assert_not_nil db_replay_start_time
    end

    if expected_db["state"] == "online"
      assert_not_nil db_replay_start_time
      assert(db_replay_start_time.to_f >= db_start_time.to_f)

      db_end_time = db["end_time"]
      assert_not_nil db_end_time
      assert(db_end_time.to_f >= db_replay_start_time.to_f)
      assert(current_time.to_f >= db_end_time.to_f)
    end

    # Loaded attributes
    db_loaded_attributes = db["ready_subdb"]["loaded_attributes"]
    assert_equal(expected_db["attributes"]["loaded"].length, db_loaded_attributes.length)
    expected_db["attributes"]["loaded"].each do |attribute_name|
      assert_attribute_loaded(db_loaded_attributes, current_time, attribute_name)
    end

    # Loading attributes
    db_loading_attributes = db["ready_subdb"]["loading_attributes"]
    assert_equal(expected_db["attributes"]["loading"].length + expected_db["attributes"]["reprocessing"].length, db_loading_attributes.length)
    expected_db["attributes"]["loading"].each do |attribute_name|
      assert_attribute_loading(db_loaded_attributes, current_time, attribute_name)
    end
    expected_db["attributes"]["reprocessing"].each do |attribute_name|
      assert_attribute_reprocessing(db_loading_attributes, current_time, attribute_name)
    end

    db_queued_attributes = db["ready_subdb"]["queued_attributes"]
    assert_equal(expected_db["attributes"]["queued"].length, db_queued_attributes.length)
    expected_db["attributes"]["queued"].each do |attribute_name|
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
    assert_equal(expected_name, attribute_name)

    # Status
    attribute_status = attribute["state"]
    assert_not_nil attribute_status
    assert_equal("loaded", attribute_status)

    # Timestamps
    attribute_loading_started = attribute["start_time"]
    assert_not_nil attribute_loading_started
    assert(attribute_loading_started.to_f > 0)

    attribute_loading_finished = attribute["end_time"]
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
    assert_equal(expected_name, attribute_name)

    # Status
    attribute_status = attribute["state"]
    assert_not_nil attribute_status
    assert_equal("reprocessing", attribute_status)

    attribute_reprocessing_progress = attribute["reprocess_progress"]
    assert_not_nil attribute_reprocessing_progress
    assert(attribute_reprocessing_progress.to_f > 0.0)
    assert(attribute_reprocessing_progress.to_f < 100.0)

    # Timestamps
    attribute_loading_started = attribute["start_time"]
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
    assert_equal(expected_name, attribute_name)

    # Status
    attribute_status = attribute["state"]
    assert_not_nil attribute_status
    assert_equal("load", attribute_status)

    # Timestamps
    attribute_loading_started = attribute["start_time"]
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
    assert_equal(expected_name, attribute_name)

    # Status
    attribute_status = attribute["state"]
    assert_not_nil attribute_status
    assert_equal("queued", attribute_status)
  end

  def get_container
    vespa.qrserver["0"] or vespa.container.values.first
  end

  def get_searchnode
    searchnode_array = @vespa.services.select {|service| service.servicetype == "searchnode"}
    assert_equal(1, searchnode_array.length)
    searchnode_array[0]
  end


end
