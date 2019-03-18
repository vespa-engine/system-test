// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.google.inject.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.jdisc.Metric;

import javax.xml.datatype.DatatypeConfigurationException;
import javax.xml.datatype.DatatypeConstants;
import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.Duration;
import java.util.concurrent.Executor;
import java.util.logging.Logger;

/**
 * @author Einar M R Rosenvinge
 * @author gv
 */
public class DatatypeHandler extends ThreadedHttpRequestHandler {
    private static final Logger log = Logger.getLogger(DatatypeHandler.class.getName());

    public static final String FACTORY_CLASS = DatatypeFactory.DATATYPEFACTORY_IMPLEMENTATION_CLASS;
    public final DatatypeFactory factory;

    @Inject
    public DatatypeHandler(DatatypeFactory factory, Executor executor, Metric metric) {
        super(executor, metric);
        this.factory = factory;
    }

    @Override
    public HttpResponse handle(HttpRequest httpRequest) {
        try {
            log.info("Result from datatypes: " + datatypes());
        } catch (DatatypeConfigurationException e) {
            throw new RuntimeException(e);
        }
        return new JaxHttpResponse(factory.getClass().getName());
    }

    String datatypes() throws DatatypeConfigurationException {
        Duration duration1 = factory.newDuration(true, 6, 5, 4, 3, 2, 1);
        Duration duration2 = factory.newDuration(true, 5, 4, 3, 2, 1, 0);
        return String.valueOf((duration1.compare(duration2) == DatatypeConstants.GREATER));
    }
}
