// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;
import org.xml.sax.SAXException;

import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.io.StringWriter;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @version $Id$
 * @since 5.1.28
 */
public class SchemaValidationHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(SchemaValidationHandler.class.getName());

    public final SchemaFactory factory;

    @Inject
    public SchemaValidationHandler(SchemaFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            log.info("Result from schema validation: " + validate(httpRequest.getData()));
        } catch (SAXException | IOException e) {
            return new JaxHttpResponse(e);
        }
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String validate(InputStream input) throws SAXException, IOException {
        Schema schema = factory.newSchema(new StreamSource(new StringReader(getSchema())));

        Validator validator = schema.newValidator();
        StringWriter writer = new StringWriter();
        StreamSource source = new StreamSource(input);
        validator.validate(source);
        return writer.toString();
    }

    private String getSchema() {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
               "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n" +
               "            xmlns:jxb=\"http://java.sun.com/xml/ns/jaxb\"\n" +
               "            jxb:version=\"2.0\">\n" +
               "\n" +
               "  <xsd:element name=\"Greetings\" type=\"GreetingListType\"/>\n" +
               "\n" +
               "  <xsd:complexType name=\"GreetingListType\">\n" +
               "    <xsd:sequence>\n" +
               "      <xsd:element name=\"Greeting\" type=\"GreetingType\"\n" +
               "                   maxOccurs=\"unbounded\"/>\n" +
               "    </xsd:sequence>\n" +
               "  </xsd:complexType>\n" +
               "\n" +
               "  <xsd:complexType name=\"GreetingType\">\n" +
               "    <xsd:sequence>\n" +
               "      <xsd:element name=\"Text\" type=\"xsd:string\"/>\n" +
               "    </xsd:sequence>\n" +
               "    <xsd:attribute name=\"language\" type=\"xsd:language\"/>\n" +
               "  </xsd:complexType>\n" +
               "\n" +
               "</xsd:schema>";
    }
}
