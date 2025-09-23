# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'

class AssembleContainerPlugin < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Test that container assembly plugin supports config definitions in bundled jars.")
  end

  def test_assemble_container_plugin
    node = vespa.nodeproxies.values.first

    node.execute("mkdir -p " + dirs.tmpdir + "/project1")
    node.copy(selfdir + '/project1', dirs.tmpdir + "/project1")
    node.execute("mkdir -p " + dirs.tmpdir + "/project2")
    node.copy(selfdir + '/project2', dirs.tmpdir + "/project2")

    install_maven_parent_pom(node)
    node.execute("cd " + dirs.tmpdir + "/project1 ; #{maven_command} clean install ; cd ..")
    node.execute("cd " + dirs.tmpdir + "/project2 ; #{maven_command} clean install ; cd ..")
    output = node.execute("cd " + dirs.tmpdir + " ; unzip -l project2/target/project2-1.0-SNAPSHOT-deploy.jar")
    assert(output.to_s =~ /.*configdefinitions\/project1.def.*/)
  end


end
