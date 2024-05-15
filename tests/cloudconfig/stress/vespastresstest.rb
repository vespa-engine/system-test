# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'cloudconfig/stress/vespa_generator'

class VespaConfigStressTest < CloudConfigTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner("musum")
    set_description("Stress tests of config system with Vespa")
  end

  def test_config_search
    orig_app = selfdir + 'vespaapp'
    project_dir = dirs.tmpdir + "project/"
    app = project_dir + 'vespaapp/'

    system("mkdir -p  + #{app}")
    system("cp -r #{orig_app} #{app}")

    services = app + 'services.xml'
    feedfile = selfdir + 'vespa_feed.json'
    sd1 = selfdir + 'sd_1/test.sd'
    sd2 = selfdir + 'sd_2/test.sd'

    generator = VespaAppGenerator.new(4, 2, ["test"])
    generator.generate_services(services)
    deploy(app, sd1)
    start
    5.times do |i|
      if i % 2 == 0
        deploy(app, sd1)
      else
        deploy(app, sd2)
      end
      feed_and_wait_for_docs("test", 1, :file => feedfile)
    end
    assert_log_not_matches(/".*Invalid\sresponse\sfrom\sconfig\sserver.*"/)
    assert_log_not_matches(/".*Timed\sout\swhile\ssubscribing\sto\sconfig.*"/)
  end

  def teardown
    stop
  end
end
