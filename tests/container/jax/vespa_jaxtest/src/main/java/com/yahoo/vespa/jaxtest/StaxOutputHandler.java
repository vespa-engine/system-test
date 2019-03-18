// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import javax.xml.stream.XMLEventFactory;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import java.io.StringWriter;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @author gv
 * @version $Id$
 * @since 5.1.29
 */
public class StaxOutputHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(StaxOutputHandler.class.getName());

    public static final String EVENT_FACTORY_CLASS = "com.sun.xml.internal.stream.events.XMLEventFactoryImpl";
    public static final String OUTPUT_FACTORY_CLASS = "com.sun.xml.internal.stream.XMLOutputFactoryImpl";

    public final XMLEventFactory eventFactory;
    public final XMLOutputFactory outputFactory;

    @Inject
    public StaxOutputHandler(XMLEventFactory eventFactory,
                             XMLOutputFactory outputFactory,
                             Executor executor,
                             Metric metric) {
        super(executor, metric);
        this.eventFactory = eventFactory;
        this.outputFactory = outputFactory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            log.info("Result from stream writer: " + output());
        } catch (XMLStreamException e) {
            throw new RuntimeException(e);
        }
        return new JaxHttpResponse(outputFactory.getClass().getName());
    }

    String output() throws XMLStreamException {
        StringWriter writer = new StringWriter();
        XMLStreamWriter xmlWriter = outputFactory.createXMLStreamWriter(writer);
        xmlWriter.writeStartDocument("UTF-8", "1.0");
        xmlWriter.writeStartElement("banana");
        xmlWriter.writeCharacters("bananarama");
        xmlWriter.writeEndElement();
        xmlWriter.writeEndDocument();
        xmlWriter.close();
        return writer.toString();
    }
}
