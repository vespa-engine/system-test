# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'testcase'
require 'environment'

class ZkReconfig < TestCase

  def setup
    set_description("dynamically reconfigure a ZK cluster, through ups and downs")
    set_owner("jonmv")
    start
  end

  def test_documentapi_java
    tmp = "#{dirs.tmpdir}/#{File.basename(selfdir)}"
    vespa.adminserver.copy("#{selfdir}/project", tmp)
    vespa.adminserver.execute("cd #{tmp}; #{maven_command} -Dtest.hide=false test")
  end

  def test_dynamic_reconfiguration
    node = vespa.nodeproxies.first[1]
    build_and_test("zookeeper_test", node)
  end

  def build_and_test(appdir, node)
    node.copy("#{selfdir}/#{appdir}/", @dirs.tmpdir + "#{appdir}/")
    dest = @dirs.tmpdir + appdir
    node.execute("cd #{dest} && #{maven_command} -Dtest.hide=false test")
  end

  def teardown
    stop
  end

end
