# Copyright Vespa.ai. All rights reserved.

require 'cloudconfig_test'

class ZkReconfig < CloudConfigTest

  def setup
    set_description("dynamically reconfigure a ZK cluster, through ups and downs")
    set_owner("jonmv")
    start
  end

  def test_dynamic_reconfiguration
    build_and_test("zookeeper_test", vespa.nodeproxies.first[1])
  end

  def build_and_test(appdir, node)
    install_maven_parent_pom(node)
    node.copy("#{selfdir}/#{appdir}/", @dirs.tmpdir + "#{appdir}/")
    dest = @dirs.tmpdir + appdir
    node.execute("cd #{dest} && #{maven_command} -Dtest.hide=false test 2>&1")
  end

  def teardown
    stop
  end

end
