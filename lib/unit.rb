# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test_result'
require 'testcase'
require 'autorunner'

if not ENV['VESPA_FACTORY_NO_AUTORUNNER']
  at_exit do
    if ENV['VESPA_FACTORY_SYSTEMTESTS_DISABLE_AUTORUN']
      puts "Factory testing enabled, AutoRunner step in exit handler skipped."
    else
      runner = AutoRunner.new
      allresults = runner.run
      failed = allresults.find { |r| r.status == "failure" }
      exit(failed ? 1 : 0)
    end
  end
end
