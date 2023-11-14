# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class PathConfig < ContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verify that components can depend on physical files using 'path' and (legacy) 'file' config.")
  end

  def test_path_config
    bundle = add_bundle_dir(selfdir, "handler")
    compile_bundles(@vespa.nodeproxies.values.first)

    start(selfdir + "app", :bundles => [bundle], :files => {selfdir + 'pathVal_1.txt' => 'file-for-pathVal.txt'})

    result = @container.search("/files")
    assert_match(Regexp.new("fileVal"), result.xmldata, "config type 'file' failed")
    assert_match(Regexp.new("pathVal_1"), result.xmldata, "config type 'path' failed")
    assert_match(Regexp.new("pathArr"), result.xmldata, "config type 'path[]' failed")
    assert_match(Regexp.new("pathMap"), result.xmldata, "config type 'path{}' failed")

    deploy(selfdir + "app", :bundles => [bundle], :files => {selfdir + 'pathVal_2.txt' => 'file-for-pathVal.txt'})
    result2 = @container.search("/files")
    assert_match(Regexp.new("pathVal_2"), result2.xmldata, "Redeploying with modified file failed")
  end

  def teardown
    stop
  end


end
