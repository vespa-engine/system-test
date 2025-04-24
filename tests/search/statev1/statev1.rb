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
    puts "Checking " + @vespa.services.length.to_s + " services"

    # As of the creation of this test, there are 9 services that are tested
    # To make sure that the test fails if the services list is empty (or fewer services than expected are added to it),
    # we add the following assert
    assert(@vespa.services.length >= 9, "The number of services that are tested should at least be 9")

    @vespa.services.each do |service|
      puts "Testing service '" + service.servicetype + "'"

      unless service.get_state_port.nil?
        # /state/v1/config
        config = get_state_v1(service, "config")
        # service should be reporting a generation
        generation = config["config"]["generation"]
        assert(!generation.nil?)

        # /state/v1/version
        version = get_state_v1(service, "version")
        # service should be reporting a version number
        version_number = version["version"]
        assert(!version_number.nil?)

        # /state/v1/health
        health = get_state_v1(service, "health")
        # service should be reporting itself as up
        assert_equal("up", health["status"]["code"])

        # /state/v1/metrics
        metrics = get_state_v1(service, "metrics")
        # service should be reporting itself as up
        assert_equal("up", metrics["status"]["code"])
      else
        puts "The service does not have a state port"
      end
    end
  end

  def get_state_v1(service, path)
    puts "Getting state/v1/" + path
    answer = nil
    assert_nothing_raised() { answer = service.get_state_v1(path) }
    assert(!answer.nil?, "Answer is nil")
    answer
  end

  def teardown
    stop
  end

end
