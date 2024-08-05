# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class CheckLogs < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Check for log messages from all services in vespa log")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def findserviceinlogfile(service)
    found = false
    @loglines.each { |line|
      fields = line.split(/\t/)
      if fields[3] == service
        puts "Found logmessage from service " + service
        return true
      end
    }
    puts "Failed to find logmessage from service " + service
    found
  end

  def test_check_for_log_from_services
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json")

    log = ""
    vespa.logserver.get_vespalog do |buf|
      log += buf
    end
    @loglines = log.split(/\n/)
    puts "Got " + @loglines.length.to_s + " log lines"

    services = get_services
    @services_without_health_check = ["adminserver", "configproxy", "storagenode"]
    @services_without_health_check << "configserver" if use_shared_configservers

    found = true
    services.each do |service|
      if @services_without_health_check.include?(service)
        puts "Skipping log check of #{service}"
      else
        puts "Checking for log from #{service}"
        found &= findserviceinlogfile(service)
      end
    end
    assert(found)
  end

  def teardown
    stop
  end

end
