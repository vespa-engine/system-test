// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;
import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @version $Id$
 * @since 5.1.28
 */
public class SaxHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(SaxHandler.class.getName());

    public static final String FACTORY_CLASS = "com.sun.org.apache.xerces.internal.jaxp.SAXParserFactoryImpl";
    public final SAXParserFactory factory;


    @Inject
    public SaxHandler(SAXParserFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        log.info("Result from SAX parser: " + saxParse(httpRequest.getData()));
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String saxParse(InputStream input) {
        try {
            SAXParser parser = factory.newSAXParser();
            ExampleSaxHandler handler = new ExampleSaxHandler();
            parser.parse(input, handler);
            return handler.string.toString();
        } catch (ParserConfigurationException | SAXException | IOException e) {
            throw new RuntimeException(e);
        }
    }

    private static class ExampleSaxHandler extends DefaultHandler {
        private StringBuilder string = new StringBuilder();
        private StringBuilder value = new StringBuilder();

        @Override
        public void startElement(String uri, String localName, String qName, Attributes attributes) throws SAXException {
            value = new StringBuilder();
        }

        @Override
        public void endElement(String uri, String localName, String qName) throws SAXException {
            String trimmedVal = value.toString().trim();
            if (!trimmedVal.isEmpty()) {
                string.append(trimmedVal).append(',');
            }
            value = new StringBuilder();
        }

        @Override
        public void characters(char[] ch, int start, int length) throws SAXException {
            value.append(ch, start, length);
        }
    }
}
