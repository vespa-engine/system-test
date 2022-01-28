# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'

class SubscribeSuperconfig < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests subscribing to config in config server's application package (superconfig)")
    @configserver = vespa.nodeproxies.first[1]
  end

  def test_endpoint_alias
    set_description("Tests setting of endpoint alias")

    jdisc_id = "foo"
    endpoint_alias = "foo1.bar.yahoo.com"
    

    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node1" />
  </admin>

  <container id="#{jdisc_id}" version="1.0">
    <search />
    <document-api />
    <aliases>
      <endpoint-alias>#{endpoint_alias}</endpoint-alias>
   </aliases>
    <nodes>
      <node hostalias="node1" />
    </nodes>
  </container>

</services>
ENDER

    deploy_generated(app, nil, {:rotations => "foo"}, nil)
    start

    config = getvespaconfig("cloud.config.lb-services", "\"*\"")
    hostname = @configserver.hostname
    endpointaliases = config["tenants"]["default"]["applications"]["default:prod:default:default"]["hosts"]["#{hostname}"]["services"]["container"]["endpointaliases"]
    assert_equal(endpoint_alias, endpointaliases[0])
  end
  
  def teardown
    stop
  end
end
