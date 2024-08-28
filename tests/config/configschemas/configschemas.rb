# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'environment'

class ConfigSchemas < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Test that changing a config definition works as expected")
  end

  def test_change_config_definition
    deploy("#{CLOUDCONFIG_DEPLOY_APPS}/base", nil)
    start
    @config_id = "myid"
    @config_name = "cloud.config.log.logd"
    @logd_def_file = "#{Environment.instance.vespa_home}/share/vespa/configdefinitions/#{@config_name}.def"

    @logd_modified_default = dirs.tmpdir + "logd_modified_default.def"
    vespa.adminserver.execute("cp #{@logd_def_file} #{@logd_modified_default}")
    vespa.adminserver.execute("sed -i #{@logd_modified_default} -e 's/default=5822/default=5888/g'")

    @logd_extra_field = dirs.tmpdir + "logd_extra_field.def"
    vespa.adminserver.execute("cp #{@logd_def_file} #{@logd_extra_field}")
    vespa.adminserver.execute("echo testfield int default=7 >> #{@logd_extra_field}")

    run_tests(19070)
    run_tests(19090)
  end

  def run_tests(port)
    # Test that default values can be modified
    assert(vespa.adminserver.execute("vespa-get-config -n #{@config_name} -i #{@config_id} -a #{@logd_modified_default} -p #{port}") =~ /logserver.rpcport 5888/)

    # Test that fields can be added
    assert(vespa.adminserver.execute("vespa-get-config -n #{@config_name} -i #{@config_id} -a #{@logd_def_file} -p #{port}") !~ /testfield/)
    assert(vespa.adminserver.execute("vespa-get-config -n #{@config_name} -i #{@config_id} -a #{@logd_extra_field} -p #{port}") =~ /testfield "7"/)
  end

  def teardown
    stop
  end

end
