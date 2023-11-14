# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'

class Integrationtests < CloudConfigTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    900
  end

  def setup
    set_description("Test and verify Java and C++ client API behavior")
    set_owner("musum")
  end

  def test_subscription
    node = vespa.nodeproxies.first[1]
    build_and_test("config_test", node)
  end

  def build_and_test(appdir, node)
    node.copy("#{selfdir}/#{appdir}/", @dirs.tmpdir + "#{appdir}/")
    dest = @dirs.tmpdir + appdir
    install_maven_parent_pom(node)
    node.execute("cd #{dest} && #{maven_command} -Dtest.hide=false test")
  end

  def teardown
      stop
  end

end
