# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class StateV1 < IndexedStreamingSearchTest

  def setup
    set_owner("boeker")
  end

  def test_availability
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start

    # Note that we do not test all services since a VespaNode object is not created for every service
    puts "Testing #{@vespa.services.length.to_s} services"

    # As a sanity check, make sure that there is at least one service being tested
    assert(@vespa.services.length > 0, "There should be at least one service being tested")

    @vespa.services.each do |service|
      puts "Testing service '#{service.servicetype}'"

      unless service.get_state_port.nil?
        puts "/state/v1/config"
        config = service.get_state_v1("config")
        # service should be reporting a generation
        generation = config["config"]["generation"]
        assert_not_nil generation

        puts "/state/v1/version"
        version = service.get_state_v1("version")
        # service should be reporting a version number
        version_number = version["version"]
        assert_not_nil version_number

        puts "/state/v1/health"
        health = service.get_state_v1("health")
        # service should be reporting itself as up
        assert_equal("up", health["status"]["code"])

        puts "/state/v1/metrics"
        metrics = service.get_state_v1("metrics")
        # service should be reporting itself as up
        assert_equal("up", metrics["status"]["code"])
      else
        puts "The service does not have a state port"
      end
    end
  end

  def test_initialization
    deploy_app(SearchApp.new.sd(selfdir + "initialization.sd"))
    start

    searchnode_array = @vespa.services.select {|service| service.servicetype == "searchnode"}
    assert_equal(1, searchnode_array.length)
    searchnode = searchnode_array[0]

    puts "/state/v1/initialization"
    initialization = searchnode.get_state_v1("initialization")
    puts JSON.pretty_generate(initialization)

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
    assert_equal(7, loaded_attributes.length)

    loading_attributes = initialization["dbs"][0]["ready_subdb"]["loading_attributes"]
    assert_equal(0, loading_attributes.length)

    queued_attributes = initialization["dbs"][0]["ready_subdb"]["queued_attributes"]
    assert_equal(0, queued_attributes.length)
  end

  def teardown
    stop
  end

end
