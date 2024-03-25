# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ConfigChange < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  def test_doctypeswitch
    puts "* Insert music doc"
    feed_and_wait_for_docs("music", 1, :file => selfdir+"music.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 1)

    puts "* Compare search result 1"
    assert_result("query=sddocname:music", selfdir+"configchange_1.json")

    puts "* Deploying application with different SD file"
    deploy_output = redeploy(SearchApp.new.sd(selfdir+"music2.sd").validation_override("content-type-removal"))

    puts "* Waiting for config to settle"
    wait_for_config(deploy_output)

    puts "* Insert music2 doc"
    feed_and_wait_for_docs("music2", 1, :file => selfdir+"music2.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music2", 1)

    puts "* Compare search result 2"
    assert_result("query=sddocname:music2", selfdir+"configchange_2.json")

    puts "* test_doctypeswitch DONE"
  end

  def wait_for_config(deploy_output)
    wait_for_application(vespa.container.values.first,
                         deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))
  end

  def teardown
    stop
  end

end
