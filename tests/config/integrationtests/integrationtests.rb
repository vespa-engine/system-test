# Copyright Vespa.ai. All rights reserved.
require 'config_test'

class Integrationtests < ConfigTest

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


end
