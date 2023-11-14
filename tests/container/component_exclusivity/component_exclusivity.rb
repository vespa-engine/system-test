# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ComponentExclusive < SearchContainerTest

  def setup
    set_owner("valerijf")
    set_description("Verify that only one instance of the component is running at a given time if it acquires lock")
    @project_dir = dirs.tmpdir + "project"
    @def_file_path = "#{@project_dir}/src/main/resources/configdefinitions"
  end

  def timeout_seconds
    return  1200
  end

  def write_def(text, filename="exclusive-hit.def")
    file = File.open("#{@def_file_path}/#{filename}", "w")
    file.print(text)
    file.close
  end

  def test_update_def
    system("mkdir -p #{@project_dir}/src")
    system("mkdir -p #{@project_dir}/app")
    system("cp -r #{selfdir}/app #{@project_dir}")
    system("cp -r #{selfdir}/src #{@project_dir}")

    write_def("namespace=vespatest\ncompId string default=\"1\"\n")
    clear_bundles
    add_bundle_dir(@project_dir, "com.yahoo.vespatest.ExclusiveHitSearcher")
    deploy(@project_dir + "/app")
    start
    verify_result("1")

    puts("Deploying with seconds version of the def-file..")
    write_def("namespace=vespatest\ncompId string default=\"2\"\n")

    # Redeploy, and verify that the searcher is updated
    clear_bundles
    add_bundle_dir(@project_dir, "com.yahoo.vespatest.ExclusiveHitSearcher")
    output = deploy(@project_dir + "/app")
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    wait_for_application(@qrs, output)
    verify_result("2")
    sleep 70
    verify_result("2")
  end

  def teardown
    stop
  end

  def verify_result(component_id)
    result = search("test")
    actual_component_id = result.hit[0].field["component_id"]
    if component_id == actual_component_id
      puts "Got expected component_id: #{component_id}"
    else
      flunk "Test failed: Expected the component id to be #{component_id}, but was #{actual_component_id}"
    end

    exclusivity_file = result.hit[0].field["exclusivity_file"]
    if exclusivity_file.include? "21"
      flunk "Test failed: Found overlapping writes to file: #{exclusivity_file}"
    else
      puts "No overlapping writes to file found!"
    end
  end

end
