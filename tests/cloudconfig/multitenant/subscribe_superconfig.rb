# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'

class SubscribeSuperconfig < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests subscribing to config in config server's application package (superconfig)")
    @configserver = vespa.nodeproxies.first[1]
  end

  def can_share_configservers?(method_name=nil)
    false # Will restart configserver to reconfigure
  end  

  def test_rotations
    set_description("Tests setting of endpoint aliases and rotations")

    jdisc_id = "foo"
    endpoint_alias = "foo1.bar.yahoo.com"
    

    app=<<ENDER
<?xml version="1.0" encoding="utf-8" ?>
<services version="1.0">

  <admin version="2.0">
    <adminserver hostalias="node1" />
  </admin>

  <jdisc id="#{jdisc_id}" version="1.0">
    <search />
    <aliases>
      <endpoint-alias>#{endpoint_alias}</endpoint-alias>
   </aliases>
    <nodes>
      <node hostalias="node1" />
    </nodes>
  </jdisc>

</services>
ENDER

    deploy_generated(app, nil, nil, {:rotations => "foo"}, nil, get_deployment(jdisc_id))
    start

    # Test rotations
    config = getvespaconfig("cloud.config.lb-services", "\"*\"")
    hostname = @configserver.hostname
    endpointaliases = config["tenants"]["default"]["applications"]["default:prod:default:default"]["hosts"]["#{hostname}"]["services"]["qrserver"]["endpointaliases"]
    assert_equal(jdisc_id, endpointaliases[0])
    assert_equal(endpoint_alias, endpointaliases[1])
  end

  def get_deployment(global_service_id)
    deployment=<<ENDER
<deployment version='1.0'>
  <test />
  <staging />
  <prod global-service-id='#{global_service_id}'>
    <region active="true">us-east</region>
    <region active="false">us-west-1</region>
  </prod>
</deployment>
ENDER
  end
  
  def teardown
    stop
  end
end
