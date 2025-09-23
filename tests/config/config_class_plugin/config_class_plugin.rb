# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'app_generator/search_app'

class ConfigClassPlugin < ConfigTest

  def setup
    set_owner("musum")
    set_description("Tests that config-class-plugin and javdoc in the created class is without warnings")
    @node = vespa.nodeproxies.first[1]
  end

  def test_create_config_class
    destproject = dirs.tmpdir + "app"
    @node.execute("mkdir -p #{destproject}")
    @node.copy(selfdir + "app", destproject)
    install_maven_parent_pom(@node)
    output = @node.execute("cd #{destproject} && #{maven_command} compile && #{maven_command} javadoc:javadoc")
    output.split("\n").each { |line|
      if line =~ /\[WARNING\] Could not apply configuration for yahoo-public-repo/ or
          line =~ /\[WARNING\] Could not transfer metadata/ or
          line =~ /Failure to transfer com.yahoo.vespa:configgen/ or
          line =~ /\[WARNING\] Checksum validation failed/ or
          line =~ /\[WARNING\] Invalid cookie header/
        next
      end
      if /WARNING/ =~ line
        assert(nil, "Warnings found, see maven command output")
      end
    }
  end


end
