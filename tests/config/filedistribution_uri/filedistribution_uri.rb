# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'json'
require 'app_generator/container_app'
require 'app_generator/search_app'

# Note: 2 hosts are needed. If you want to run this by yourself you need to add "--configserverhost some_other_host"
class FileDistributionUri < ConfigTest

  def can_share_configservers?
    true
  end

  def setup
    set_owner("musum")
    set_description("Tests file distribution with uri")
    @valgrind = false
  end

  # Tests getting a file via a https uri (a constant tensor)
  def test_filedistribution_uri_https
    deploy_app(SearchApp.new().sd(selfdir + 'tensor-from-uri-https-sd/tensor_from_uri.sd'))
    start
    feed_and_wait_for_docs("tensor_from_uri", 1, :file => selfdir + "docs.json")
  end

  def teardown
    stop
  end

end
