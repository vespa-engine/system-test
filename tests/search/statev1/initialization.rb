# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Initialization < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
  end

  def test_initialization
    deploy_app(SearchApp.new.sd(selfdir + "initialization.sd"))
    start

    dbs = { "initialization" => ["int_field1", "string_field1", "string_field3", "tensor_field"] }

    searchnode = get_searchnode

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_loaded(initialization, dbs)

    # Feed a document
    doc = Document.new("id:initialization:initialization::0")
                  .add_field("int_field1", "1")
                  .add_field("string_field1", "foo")
                  .add_field("string_field2", "bar")
                  .add_field("string_field3", "baz")
                  .add_field("tensor_field", [1, 2, 3])
    vespa.document_api_v1.put(doc)

    # Restart without flushing
    restart_vespa
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_loaded(initialization, dbs)

    # Flush and restart Vespa
    searchnode.trigger_flush
    restart_vespa
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_loaded(initialization, dbs)
  end

  def test_multiple_schemas
    deploy(selfdir + "multiple_schemas/")
    start

    dbs = {
      "foo" => ["int_foo1", "string_foo1", "string_foo3", "tensor_foo"],
      "bar" => ["int_bar1", "string_bar1", "string_bar3", "tensor_bar"]
    }

    searchnode = get_searchnode

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_loaded(initialization, dbs)

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
    searchnode.trigger_flush
    restart_vespa
    puts "Waiting for 1 hit per schema"
    wait_for_atleast_hitcount("query=sddocname:foo", 1)
    wait_for_atleast_hitcount("query=sddocname:bar", 1)
    puts "Waited for 1 hit per schema"

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_loaded(initialization, dbs)
  end


  def restart_vespa
    puts "# Stopping Vespa"
    vespa.stop_base
    vespa.adminserver.stop_configserver(:keep_everything => true)
    puts "# Starting Vespa"
    vespa.adminserver.start_configserver
    vespa.adminserver.ping_configserver
    vespa.start_base

    puts "# Wait until ready"
    wait_until_ready
    puts "# System is up"
  end

  def assert_loaded(initialization, expected_dbs)
    # Overall state
    assert_not_nil(initialization["state"])
    assert_equal("ready", initialization["state"])

    # Timestamps
    start_time = initialization["start_time"]
    assert_not_nil start_time
    assert start_time.to_f > 0

    end_time = initialization["end_time"]
    assert_not_nil end_time
    assert end_time.to_f >= start_time.to_f

    current_time = initialization["current_time"]
    assert_not_nil current_time
    assert current_time.to_f >= end_time.to_f

    dbs = initialization["dbs"]
    assert_not_nil dbs
    assert_equal(dbs.length, expected_dbs.length)

    expected_dbs.each do |expected_name, expected_attribute_names|
      assert_db_loaded(dbs, current_time, expected_name, expected_attribute_names)
    end
  end

  def assert_db_loaded(dbs, current_time, expected_name, expected_attribute_names)
    # Get status of db "name"
    name_db = nil
    dbs.each do |db|
      assert_not_nil db["name"]
      if db["name"] == expected_name
        name_db = db
      end
    end

    assert_not_nil name_db
    assert_specific_db_loaded(name_db, current_time, expected_name, expected_attribute_names)
  end

  def assert_specific_db_loaded(db, current_time, expected_name, expected_attribute_names)
    # Name
    db_name = db["name"]
    assert_not_nil db_name
    assert_equal(db_name, expected_name)

    # State
    db_state = db["state"]
    assert_not_nil db_state
    assert_equal(db_state, "ready")

    # Replay progress
    db_replay_progress = db["replay_progress"]
    assert_not_nil db_replay_progress
    assert((db_replay_progress.to_f - 1.0).abs < 0.001)

    # Timestamps
    db_start_time = db["start_time"]
    assert_not_nil db_start_time
    assert(db_start_time.to_f > 0)

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

    # Attributes
    db_loaded_attributes = db["ready_subdb"]["loaded_attributes"]

    # Check that the number of attributes is corrected
    assert_equal(db_loaded_attributes.length, expected_attribute_names.length)

    # Check that all attributes actually occur
    expected_attribute_names.each do |attribute_name|
      assert_attribute_loaded(db_loaded_attributes, current_time, attribute_name)
    end

    db_loading_attributes = db["ready_subdb"]["loading_attributes"]
    assert_equal(db_loading_attributes.length, 0)

    db_queued_attributes = db["ready_subdb"]["queued_attributes"]
    assert_equal(db_queued_attributes.length, 0)
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

  def get_searchnode
    searchnode_array = @vespa.services.select {|service| service.servicetype == "searchnode"}
    assert_equal(1, searchnode_array.length)
    searchnode_array[0]
  end

  def teardown
    stop
  end

end
