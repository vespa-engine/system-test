# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'environment'

# Test for possibility of XML eXternal Entity attack
# see http://www.securiteam.com/securitynews/6D0100A5PU.html
class XXEAttack < SearchTest

  def setup
    set_owner("musum")
    set_description("Test if XML eXternal Entity are expanded by the vespa http client")
    deploy_app(SearchApp.new.
               sd(selfdir + "music.sd").
               enable_document_api)
    start
  end

  def test_xxe_vespa_http_client
    vespa.adminserver.copy("#{selfdir}scary.txt", Environment.instance.vespa_home)
    vespa.adminserver.wait_until_file_exists(Environment.instance.vespa_home + "/scary.txt", 5)

    feedfile(selfdir+"musicxxe.xml", :client => :vespa_http_client)

    wait_for_hitcount("query=exploit", 1)
    assert_hitcount("query=scary", 0)
  end

  def teardown
    vespa.adminserver.execute("rm -f #{Environment.instance.vespa_home}/scary.txt")
    stop
  end

end
