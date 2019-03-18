// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMResult;
import javax.xml.transform.stream.StreamSource;
import java.io.InputStream;
import java.util.concurrent.Executor;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @version $Id$
 * @since 5.1.29
 */
public class TransformerHandler extends ThreadedHttpRequestHandler {

    public final static String FACTORY_CLASS = "com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl";
    final TransformerFactory factory;

    @Inject
    public TransformerHandler(TransformerFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            log.info("Result from transform: " + transform(httpRequest.getData()));
        } catch (TransformerException e) {
            throw new RuntimeException(e);
        }
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String transform(InputStream input) throws TransformerException {
        Transformer transformer = factory.newTransformer();

        DOMResult domResult = new DOMResult();
        transformer.transform(new StreamSource(input), domResult);
        StringBuilder b = new StringBuilder();
        DomHandler.domValues(domResult.getNode(), b);
        return b.toString();
    }
}
