# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class Initialization < IndexedOnlySearchTest

  def setup
    set_owner("boeker")
  end

  def test_initialization
    deploy_app(SearchApp.new.sd(selfdir + "initialization.sd"))
    start

    searchnode_array = @vespa.services.select {|service| service.servicetype == "searchnode"}
    assert_equal(1, searchnode_array.length)
    searchnode = searchnode_array[0]

    puts "/state/v1/initialization"

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_initialization_finished(initialization)

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
    assert_initialization_finished(initialization)

    # Flush and restart Vespa
    vespa.search["search"].first.trigger_flush
    restart_vespa
    puts "Waiting for 1 hit"
    wait_for_atleast_hitcount("query=sddocname:initialization", 1)
    puts "Waited for 1 hit"

    # Verify that initialization status is as expected
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)
    assert_initialization_finished(initialization)
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

  def assert_initialization_finished(initialization)
    # overall state
    assert_not_nil(initialization["state"])
    assert_equal("ready", initialization["state"])

    # time
    assert_not_nil(initialization["start_time"])
    start_time = initialization["start_time"].to_f
    assert(start_time > 0)

    assert_not_nil(initialization["end_time"])
    end_time = initialization["end_time"].to_f
    assert(end_time >= start_time)

    assert_not_nil(initialization["current_time"])
    current_time = initialization["current_time"].to_f
    assert(current_time >= end_time)

    # db
    assert_not_nil(initialization["dbs"][0]["state"])
    assert_equal("ready", initialization["dbs"][0]["state"])
    assert_not_nil(initialization["dbs"][0]["name"])
    assert_equal("initialization", initialization["dbs"][0]["name"])

    # replay_progress for db
    assert_not_nil(initialization["dbs"][0]["replay_progress"])
    replay_progress = initialization["dbs"][0]["replay_progress"].to_f
    assert((replay_progress - 1.0).abs < 0.001)

    # time for db
    assert_not_nil(initialization["dbs"][0]["start_time"])
    start_time = initialization["dbs"][0]["start_time"].to_f
    assert(start_time > 0)

    assert_not_nil(initialization["dbs"][0]["replay_start_time"])
    replay_start_time = initialization["dbs"][0]["replay_start_time"].to_f
    assert(replay_start_time >= start_time)

    assert_not_nil(initialization["dbs"][0]["replay_end_time"])
    replay_end_time = initialization["dbs"][0]["replay_end_time"].to_f
    assert(replay_end_time >= replay_start_time)

    assert_not_nil(initialization["dbs"][0]["end_time"])
    end_time = initialization["dbs"][0]["end_time"].to_f
    assert(end_time >= replay_end_time)
    assert(current_time >= end_time)

    # attributes
    loaded_attributes = initialization["dbs"][0]["ready_subdb"]["loaded_attributes"]
    assert_equal(4, loaded_attributes.length)

    # check that all attributes occur
    assert_loaded_attribute(loaded_attributes, "int_field1")
    assert_loaded_attribute(loaded_attributes, "string_field1")
    assert_loaded_attribute(loaded_attributes, "string_field3")
    assert_loaded_attribute(loaded_attributes, "tensor_field")

    # since we made sure that there only 4 attributes,
    # we implicitly checked that string_field2 does not occur
    # (field string_field2 is not an attribute)

    loading_attributes = initialization["dbs"][0]["ready_subdb"]["loading_attributes"]
    assert_equal(0, loading_attributes.length)

    queued_attributes = initialization["dbs"][0]["ready_subdb"]["queued_attributes"]
    assert_equal(0, queued_attributes.length)
  end

  def assert_loaded_attribute(loaded_attributes, name)
    loaded_attributes.each do |attribute|
      assert_not_nil attribute["name"]
      if attribute["name"] == name
        assert_not_nil attribute["status"]
        status = attribute["status"]
        assert_equal(status, "loaded")

        loading_started = attribute["loading_started"]
        assert_not_nil loading_started

        loading_finished = attribute["loading_finished"]
        assert_not_nil loading_finished

        assert loading_finished.to_f >= loading_started.to_f
      end
    end

    false
  end

  def teardown
    stop
  end

end
