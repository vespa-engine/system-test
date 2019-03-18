// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;
import java.io.InputStream;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @version $Id$
 * @since 5.1.28
 */
public class StaxHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(StaxHandler.class.getName());

    public static final String FACTORY_CLASS = "com.sun.xml.internal.stream.XMLInputFactoryImpl";
    public final XMLInputFactory factory;

    @Inject
    public StaxHandler(XMLInputFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        log.info("Result from stax parser: " + staxParse(httpRequest.getData()));
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String staxParse(InputStream input) {
        try {
            XMLStreamReader reader = factory.createXMLStreamReader(input);
            StringBuilder string = new StringBuilder();
            StringBuilder currentText = new StringBuilder();
            while (reader.hasNext()) {
                int type = reader.next();
                if (type == XMLStreamConstants.CHARACTERS) {
                    if (reader.hasText()) {
                        currentText.append(reader.getText());
                    }
                } else if (type == XMLStreamConstants.START_ELEMENT) {
                    currentText = new StringBuilder();  //probably not necessary
                } else if (type == XMLStreamConstants.END_ELEMENT) {
                    String trimmedVal = currentText.toString().trim();
                    if (!trimmedVal.isEmpty()) {
                        string.append(trimmedVal).append(',');
                    }
                    currentText = new StringBuilder();
                }
            }
            return string.toString();
        } catch (XMLStreamException e) {
            throw new RuntimeException(e);
        }
    }
}
