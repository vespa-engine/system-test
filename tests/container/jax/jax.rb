# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_container_test'
require 'app_generator/container_app'

class Jax < SearchContainerTest

  def setup
    set_owner("gjoranv")
    set_description("Verifies that a handler can have Java XML factories injected.")
    add_bundle_dir(selfdir + "vespa_jaxtest", "vespa_jaxtest")
    deploy_app(
        ContainerApp.new.container(
            Container.new("default").
                search(Searching.new).
                handler(Handler.new("com.yahoo.vespa.jaxtest.DatatypeHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/datatype")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.DomHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/dom")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.SaxHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/sax")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.SchemaValidationHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/schema")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.StaxHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/stax")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.StaxOutputHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/staxoutput")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.TransformerHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/transformer")).
                handler(Handler.new("com.yahoo.vespa.jaxtest.XPathHandler").
                                    bundle("vespa_jaxtest").
                                    binding("http://*/xpath"))).
            logserver("node1")
    )
    start
  end

  def test_jax
    wait_for_hitcount("query=test",0)  # Just wait for the Qrs to be up
    verify_handler_response("datatype", "com.sun.org.apache.xerces.internal.jaxp.datatype.DatatypeFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.DatatypeHandler.+Result from datatypes: true"))
    verify_handler_response("dom", "com.sun.org.apache.xerces.internal.jaxp.DocumentBuilderFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.DomHandler.+Result from dom parsing: foo,bar,"))
    verify_handler_response("sax", "com.sun.org.apache.xerces.internal.jaxp.SAXParserFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.SaxHandler.+Result from SAX parser: foo,bar,"))
    verify_handler_response("schema", "com.sun.org.apache.xerces.internal.jaxp.validation.XMLSchemaFactory")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.SchemaValidationHandler.+Result from schema validation: "))
    verify_handler_response("stax", "com.sun.xml.internal.stream.XMLInputFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.StaxHandler.+Result from stax parser: foo,bar,"))
    verify_handler_response("staxoutput", "com.sun.xml.internal.stream.XMLOutputFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.StaxOutputHandler.+Result from stream writer: \\<\\?xml version=\"1.0\" encoding=\"UTF-8\"\\?\\>\\<banana\\>bananarama\\</banana\\>"))
    verify_handler_response("transformer", "com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.TransformerHandler.+Result from transform: foo,bar,"))
    verify_handler_response("xpath", "com.sun.org.apache.xpath.internal.jaxp.XPathFactoryImpl")
    assert_log_matches(Regexp.compile("Container.com.yahoo.vespa.jaxtest.XPathHandler.+Result from xpath: foo"))
  end

  def verify_handler_response(apiname, expected)
    @qrs = (vespa.qrserver.values.first or vespa.container.values.first)
    result = @qrs.post_search("/#{apiname}", get_xml())
    if expected == result.xmldata
      puts "Got expected response: #{expected}"
      return;
    end
    flunk "Did not get expected response, got #{result.xmldata}"
  end

  def get_xml()
    return "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n" +
                "<Greetings>\n" +
                "  <Greeting>\n" +
                "    <Text>foo</Text>\n" +
                "  </Greeting>\n" +
                "  <Greeting>\n" +
                "    <Text>bar</Text>\n" +
                "  </Greeting>\n" +
                "</Greetings>\n"
  end

  def teardown
    stop
  end

end
