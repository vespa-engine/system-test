# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'environment'

class CoredumpsTest < SearchTest

  def setup
    @files = []
  end

  def test_java_core
    path = "#{Environment.instance.vespa_home}/var/crash/hs_err_pid1234.log"
    @files << path
    File.open(path, 'w') do |f|
      f.write("dummy content, hs err pid 1234 log")
    end
  end

  def teardown

  end
end
