# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class Watchdog < ContainerTest

  def setup
    set_owner("bjorncs")
    set_description("Verify watchdog warns on leaked resources to log")
  end

  def test_thread_leak_detection
    handler_file = selfdir + "HandlerLeakingThreads.java"
    add_bundle(handler_file)
    app = ContainerApp.new.container(
      Container.new.
        handler(Handler.new("com.yahoo.vespatest.HandlerLeakingThreads").
          binding("http://*/leak")))
    start(app)

    # Rebuild and redeploy app. Modify Java code to build to new bundle.
    text = File.read(handler_file)
    new_contents = text.gsub("I leak", "I leak again")
    File.open(handler_file, "w") {|file| file.puts new_contents }
    deploy(app)

    assert_log_matches(
      /Thread 'leak-using-runnable' using bundle 'com.yahoo.vespatest.HandlerLeakingThreads \[.+\]'/, 90)
    assert_log_matches(
      /Thread 'leak-using-subclass' using bundle 'com.yahoo.vespatest.HandlerLeakingThreads \[.+\]'/, 1)
  end

  def teardown
    stop
  end

end
