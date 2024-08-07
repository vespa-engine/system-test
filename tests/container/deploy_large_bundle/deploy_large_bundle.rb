# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class DeployLargeBundle < SearchContainerTest

  def timeout_seconds
    return 1600
  end

  def setup
    set_owner("musum")
    set_description("Tests that it is possible to deploy large bundle (e.g it must not be copied to zk)")
  end

  def test_deploy_large_bundle_and_modular_config
    project_dir = dirs.tmpdir + "project/"
    system("mkdir -p " + project_dir + "src")
    system("mkdir -p " + project_dir + "app-modular")
    system("cp -r #{selfdir}/app-modular #{project_dir}")
    system("cp -r #{selfdir}/src #{project_dir}")

    resourcesDir = project_dir + "src/main/resources"
    create_large_resources_file(resourcesDir)
    bundle = add_bundle_dir(File.expand_path(project_dir), "mybundle")
    deploy(project_dir + "app-modular")
    start

    result = search("query=test&searchChain=inline")
    assert(result.hit.length==2)
    message = result.hit[0].field["message"]
    message2 = result.hit[1].field["message2"]
    assert_equal("Hello world", message)
    assert_equal("Hello world 2", message2)
  end

  def create_large_resources_file(resourcesPath)
    FileUtils.mkdir_p(resourcesPath)
    `dd if=/dev/urandom of=#{resourcesPath + "/random.txt"} bs=1 count=#{10*1024*1024}`
  end

  def teardown
    stop
  end
end
