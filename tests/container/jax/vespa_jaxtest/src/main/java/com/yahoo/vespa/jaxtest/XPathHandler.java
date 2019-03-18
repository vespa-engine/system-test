// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;
import org.xml.sax.InputSource;

import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;
import java.io.InputStream;
import java.util.concurrent.Executor;

/**
 * @author <a href="mailto:einarmr@yahoo-inc.com">Einar M R Rosenvinge</a>
 * @version $Id$
 * @since 5.1.28
 */
public class XPathHandler extends ThreadedHttpRequestHandler {

    public static final String FACTORY_CLASS = "com.sun.org.apache.xpath.internal.jaxp.XPathFactoryImpl";
    final XPathFactory factory;

    @Inject
    public XPathHandler(XPathFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            log.info("Result from xpath: " + parse(httpRequest.getData()));
        } catch (XPathExpressionException e) {
            throw new RuntimeException(e);
        }
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String parse(InputStream input) throws XPathExpressionException {
        XPath xpath = factory.newXPath();
        return xpath.evaluate("Greetings/Greeting/Text/text()", new InputSource(input));
    }
}
