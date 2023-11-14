// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.vespatest.ExceptionConfig;

public class ConfigurableExceptionHandler extends AbstractRequestHandler {

    private final int generation;

    public ConfigurableExceptionHandler(ExceptionConfig config) {
        if (config.doThrow())
            throw new RuntimeException();

        generation = config.generation();
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("Ok" + generation);
        writer.close();
        return null;
    }
}
