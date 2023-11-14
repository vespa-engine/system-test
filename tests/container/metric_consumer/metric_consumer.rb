# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class MyComponent
  include ChainedSetter

  chained_forward :config, :config => :add

  def initialize(id, classId = nil)
    @id = id
    @classId = classId != nil ? classId : id
    @config = ConfigOverrides.new
  end
  
  def to_xml(indent)
    XmlHelper.new(indent).
      tag("component", :id => @id, :class => @classId).
      to_xml(@config).
      close_tag.to_s
  end
end

class MetricConsumer < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Deploy a custom metric consumer, and ensure that it is exercised.")
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.LoggingMetricConsumer")
    deploy_app(ContainerApp.new.
               container(Container.new.
                         component(MyComponent.new("foo", "com.yahoo.vespatest.LoggingMetricConsumer").
                                   config(ConfigOverride.new("com.yahoo.vespatest.logging-metric-consumer").
                                          add("name", "foo"))).
                         component(MyComponent.new("bar", "com.yahoo.vespatest.LoggingMetricConsumer").
                                   config(ConfigOverride.new("com.yahoo.vespatest.logging-metric-consumer").
                                          add("name", "bar")))))
    start
  end

  def test_metric_consumer
    result = search("/ApplicationStatus");
    puts ">>>>> /ApplicationStatus"
    puts result
    puts "<<<<<"

    # TODO: assert that metric consumers are part of the component graph
    
    wait_for_metric_log("foo")
    wait_for_metric_log("bar")
  end

  def wait_for_metric_log(name, timeout = 120)
    regexp = Regexp.new("#{name}Consumer,set,.+,.+,#{name}Context");

    matches = vespa.logserver.log_matches(regexp)
    endtime = Time.now.to_i + timeout.to_i
    while (Time.now.to_i < endtime) && (matches == 0)
      sleep 1
      matches = vespa.logserver.log_matches(regexp)
    end
    assert(matches > 0, "#{regexp} produced no matches in the log")
  end

  def teardown
    stop
  end

end
