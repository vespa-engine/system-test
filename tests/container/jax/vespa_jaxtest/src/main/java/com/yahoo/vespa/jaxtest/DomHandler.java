// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;
import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author Einar M R Rosenvinge
 */
public class DomHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(DomHandler.class.getName());

    public static final String FACTORY_CLASS = "com.sun.org.apache.xerces.internal.jaxp.DocumentBuilderFactoryImpl";
    public final DocumentBuilderFactory factory;

    @Inject
    public DomHandler(DocumentBuilderFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        log.info("Result from dom parsing: " + domParse(httpRequest.getData()));
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String domParse(InputStream input) {
        try {
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document doc = builder.parse(input);
            StringBuilder str = new StringBuilder();
            domValues(doc.getDocumentElement(), str);
            return str.toString();
        } catch (ParserConfigurationException | SAXException | IOException e) {
            throw new RuntimeException(e);
        }
    }

    static void domValues(Node node, StringBuilder string) {
        // do something with the current node instead of System.out
        if (node.getNodeValue() != null) {
            String val = node.getNodeValue().trim();
            if (!val.isEmpty()) {
                string.append(val).append(',');
            }
        }

        NodeList nodeList = node.getChildNodes();
        for (int i = 0; i < nodeList.getLength(); i++) {
            Node currentNode = nodeList.item(i);
            //calls this method for all the children which is Element
            domValues(currentNode, string);
        }
    }
}
