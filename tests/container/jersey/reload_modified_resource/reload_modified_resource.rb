# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class ReloadModifiedResource < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that rest-api components are updated after redeploying application with a different resource")
    @project_dir = dirs.tmpdir + "project/"
    system("mkdir -p " + @project_dir + "resource_bundle")
    system("mkdir -p " + @project_dir + "app")
    system("cp -r #{selfdir}/app #{@project_dir}")
    system("cp -r #{selfdir}/resource_bundle #{@project_dir}")
    @resource_src_dir = @project_dir + "/resource_bundle/src/"
    @resource_dir = @resource_src_dir + "main/java/com/yahoo/test/rest-api/"
    @resource_file = "HelloResource.java"
  end

  def test_reload_modified_resource_bundle
    deploy_resource_app("Resource1")
    start
    @container = vespa.container.values.first
    check_result('1')

    output = deploy_resource_app("Resource2")
    wait_for_application(@container, output)
    check_result('2')
  end

  def deploy_resource_app(resource_file)
    FileUtils.mkdir_p(@resource_dir)
    FileUtils.cp(selfdir + resource_file + ".java", @resource_dir + @resource_file)
    add_bundle_dir(@project_dir + "resource_bundle", "resource_bundle")
    deploy(@project_dir + "app")
  end

  def check_result(resource_no)
    result = @container.search("/rest-api/hello")
    assert_match(Regexp.new("Hello from resource #{resource_no}"), result.xmldata, "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
