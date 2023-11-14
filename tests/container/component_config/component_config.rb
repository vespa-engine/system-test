# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'environment'

class ComponentConfig < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify re-deployment of modified searcher config, unmodified bundle. Plus ApplicationStatus handler output.")

    @searcher = add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.ExtraHitSearcher", :name => 'searcher')
    compile_bundles(@vespa.nodeproxies.values.first)
  end

  def test_component_config
    output = deploy(selfdir + "app", nil, :bundles => [@searcher])
    start
    @container = (vespa.qrserver.values.first or vespa.container.values.first)
    wait_for_application(@container, output)

    # title uses a config with namespace= inn config def, title2 uses a config with package= in config def
    verify_result("title", "Heal the World!")
    verify_result("title2", "Heal the Body!")
    assert_equal("app-component_config", @container.get_application_version)

    for i in (1..2)
      puts ">>>>>>>>>>>> Deploying app_II for the #{i}. time"
      output = deploy(selfdir + "app_II", nil, :bundles => [@searcher])
      wait_for_application(@container, output)
      verify_result("title", "(adding a newline, see ticket 3378196)\nHeal the Mind!")
      assert_equal("app_II-component_config", @container.get_application_version)

      puts ">>>>>>>>>>>> Deploying the original app for the #{i+1}. time"
      output = deploy(selfdir + "app", nil, :bundles => [@searcher])
      wait_for_application(@container, output)
      verify_result("title", "Heal the World!")
      assert_equal("app-component_config", @container.get_application_version)
    end
  end

  def test_component_config_with_missing_value
    set_expected_logged(/JDisc exiting: Throwable caught/)
    deploy(selfdir + "app_with_missing_config_value", nil, :bundles => [@searcher])
    begin
      start(30)
    rescue Exception => e
      # Expected to fail
    end
    assert_log_matches(/The following builder parameters for extra-hit must be initialized: \[enumVal\]/)
  end

  def verify_result(field, expected)
    result = search("query=test")
    actual = result.hit[0].field[field]
    puts "Got response: '#{actual}' - expected: '#{expected}'"
    if expected != actual
      puts "xxxxxxxxxxxxx  Writing jstack output to file   xxxxxxxxxxxxxx"
      qrsPid = @container.execute("pgrep -f -o prelude")
      f = File.new(selfdir+"/jstack.out", "w")
      f.puts(@container.execute("/usr/bin/sudo -u #{Environment.instance.vespa_user} jstack -l #{qrsPid}"))
      f.close
      flunk "Did not get expected response"
    end
  end

  def teardown
    stop
  end

end
