# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'environment'

class ComponentConfig < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify re-deployment of modified searcher config, unmodified bundle. Plus ApplicationStatus handler output.")

    @searcher = add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.ExtraHitSearcher", :name => 'searcher')
    compile_bundles(@vespa.nodeproxies.values.first)

    output = deploy(selfdir + "app", nil, nil, :bundles => [@searcher])
    start
    @container = vespa.qrserver.values.first
    wait_for_application(@container, output)
  end

  def test_component_config
    verify_result("Heal the World!")
    assert_equal("app-component_config", @container.get_application_version)

    for i in (1..2)
      puts ">>>>>>>>>>>> Deploying app_II for the #{i}. time"
      output = deploy(selfdir + "app_II", nil, nil, :bundles => [@searcher])
      wait_for_application(@container, output)
      verify_result("(adding a newline, see ticket 3378196)\nHeal the Mind!")
      assert_equal("app_II-component_config", @container.get_application_version)

      puts ">>>>>>>>>>>> Deploying the original app for the #{i+1}. time"
      output = deploy(selfdir + "app", nil, nil, :bundles => [@searcher])
      wait_for_application(@container, output)
      verify_result("Heal the World!")
      assert_equal("app-component_config", @container.get_application_version)
    end
  end

  def verify_result(expected)
    result = search("query=test")
    actual = result.hit[0].field["title"]
    puts "Got response: '#{actual}' - expected: '#{expected}'"
    if expected != actual
      puts "xxxxxxxxxxxxx  Writing jstack output to file   xxxxxxxxxxxxxx"
      qrsPid = @container.execute("pgrep -f -o prelude")
      f = File.new(selfdir+"/jstack.out", "w")
      f.puts(@container.execute("sudo -u #{Environment.instance.vespa_user} jstack -l #{qrsPid}"))
      f.close
      flunk "Did not get expected response"
    end
  end

  def teardown
    stop
  end

end
