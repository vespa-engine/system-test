# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'environment'

class VespaNamespace < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Require that all installed config definitions are in " +
                    "the vespa.config.x namespace.")
  end

  def test_vespa_namespace
    vespa_namespace = "^namespace=vespa\\.config\\.[a-z]+$"
    config_db = "#{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/serverdefs"
    bad_defs = ""

    node = vespa.nodeproxies.values.first
    Dir.glob("#{config_db}/*.def") do |config_def|
      begin
        node.execute("grep -E \"#{vespa_namespace}\" #{config_def}",
                     :noecho => true)
      rescue ExecuteError => e
        bad_ns = node.execute("grep namespace= #{config_def}", 
                              :exceptiononfailure => false,
                              :noecho => true)
        bad_ns.chomp!
        bad_defs += "#{config_def}: #{bad_ns}\n"
      end
    end
    if (!bad_defs.empty?)
      puts "\nBAD NAMESPACE IN FILES:"
      puts bad_defs
      assert_equal(true, false)
    end
  end

  def teardown
    stop
  end

end
