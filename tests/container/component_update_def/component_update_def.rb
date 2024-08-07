# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class ComponentUpdateDef < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that the set of bundled def files can be changed betweeen deploy/reloads")
    @project_dir = dirs.tmpdir + "project"
    @def_file_path = "#{@project_dir}/src/main/resources/configdefinitions"
  end

  def timeout_seconds
    return  1200
  end

  def write_def(text, filename="extra-hit.def")
    file = File.open("#{@def_file_path}/#{filename}", "w")
    file.print(text)
    file.close
  end

  def test_update_def
    system("mkdir -p #{@project_dir}/src")
    system("mkdir -p #{@project_dir}/app")
    system("cp -r #{selfdir}/app #{@project_dir}")
    system("cp -r #{selfdir}/src #{@project_dir}")

    write_def("namespace=vespatest\nexampleString string default=\"version one\"\n")
    clear_bundles
    add_bundle_dir(@project_dir, "com.yahoo.vespatest.ExtraHitSearcher")
    deploy(@project_dir + "/app")
    start
    verify_result("version one")

    puts("Deploying with seconds version of the def-file..")
    write_def("namespace=vespatest\nexampleString string default=\"version two\"\n")

    # Redeploy, and verify that the searcher is updated
    clear_bundles
    add_bundle_dir(@project_dir, "com.yahoo.vespatest.ExtraHitSearcher")
    output = deploy(@project_dir + "/app")

    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    wait_for_application(@qrs, output)
    verify_result("version two")
  end

  def teardown
    stop
  end

  def verify_result(expected)
    result = search("query=test")
    actual = result.hit[0].field["title"]
    if expected == actual
      puts "Got expected response: #{expected}"
      return;
    end

    flunk "Test failed: Did not get expected result: #{expected}, got: #{result.xmldata}"
  end

end
