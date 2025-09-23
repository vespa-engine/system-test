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


end
