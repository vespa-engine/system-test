# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'environment'

class ConfigDefinitionsNotChangingTest < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_config_definitions_not_changing
    set_description("Test that the config definitions used for persisted config in proton do not change")
    # NOTE: If this test fails a config definition file has changed.
    # The only compatible change we can do to a config definition file is adding new keys (with default values).
    # If a compatible change has been made, update the versions file of this test.
    # If a non-compatible change has been made, this must be reverted. Older persisted configs on a live system must
    # be compatible with a new config definition file that is introduced with a Vespa upgrade.
    deploy_app(SearchApp.new.sd(SEARCH_DATA + "test.sd"))
    start

    dir_name = Environment.instance.vespa_home + "/share/vespa/configdefinitions";
    configs = [ "vespa.config.search.rank-profiles", 
                "vespa.config.search.indexschema", 
                "vespa.config.search.attributes", 
                "vespa.config.search.summary", 
                "vespa.config.search.summary.juniperrc", 
                "document.documenttypes" ]
    mymd5cmd = "cd #{dir_name} && md5sum " + configs.join(".def ") + ".def"

    act_content = vespa.adminserver.execute(mymd5cmd).split("\n")
    for i in 0..act_content.size-1
      act_content[i] += "\n"
    end
    puts "config definition versions:\n#{act_content}"
    exp_content = File.open(selfdir + "configdefs-md5.txt", "r").readlines
    assert_equal(exp_content.size, act_content.size)
    for i in 0..exp_content.size
      assert_equal(exp_content[i], act_content[i])
    end
  end

  def teardown
    stop
  end

end
