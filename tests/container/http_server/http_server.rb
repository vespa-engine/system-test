# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'
require 'set'

class HttpServer < SearchContainerTest

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("gjoranv")
    set_description("Test HttpServer reconfiguration behavior.")
    add_bundle_dir(File.expand_path(selfdir), "test.OutputHttpServerIdentity")
  end

  def deploy_generation(generation)
    deploy_app(ContainerApp.new.
               container(Container.new.
                         documentapi(ContainerDocumentApi.new).
                         search(Searching.new.
                                chain(Chain.new("default").
                                      add(Searcher.new("test.OutputHttpServerIdentity").
                                          config(ConfigOverride.new("com.yahoo.test.generation").
                                                 add("generation", generation)))))))
  end

  def test_http_servers_are_not_recreated_when_reconfiguring
    deploy_generation("1")
    start

    httpServerIdentitiesGen1 = httpServerIdentities()

    deploy_generation("2")
    wait_for_next_application_switch('container', 1)

    httpServerIdentitiesGen2 = httpServerIdentities()

    assert_equal(httpServerIdentitiesGen1, httpServerIdentitiesGen2,
                 "The http servers have been reinstantiated.")
  end

  def httpServerIdentities()
    set = Set.new
    result = search("")
    result.hit.each { |h| set.add(h.field['identityHashCode']) }
    return set
  end

  def wait_for_next_application_switch(app, switches_until_now)
    switches_now = 0
    count = 0
    while count < 90
      begin
        count = count + 1
        switches_now = num_application_switches(app)
        if switches_now < switches_until_now+1
          puts "* Try #{count}, waiting for application switch no. #{switches_until_now+1} for application #{app}, got #{switches_now}"
          sleep 1
        else
          puts "Got application switch no. #{switches_now} for application #{app}"
          break
        end
      end
    end
    if (switches_now < switches_until_now+1)
      flunk "Did not get application switch no. #{switches_until_now+1} in #{count} seconds"
    elsif (switches_now > switches_until_now+1)
      flunk "Got #{switches_now} switches when waiting for switch no. #{switches_until_now+1}"
    end
  end

  # Count number of "Switched to the latest deployed ..." messages in vespa.log
  def num_application_switches(app)
    regex = Regexp.new(".*\\s#{app}\\s.+Switching to the latest deployed")
    log = ''
    num_switches = 0
    vespa.logserver.get_vespalog { |data|
      log << data
      nil
    }

    log.each_line do |line|
      num_switches += 1 if regex.match(line)
    end

    return num_switches
  end

  def teardown
    stop
  end

end
