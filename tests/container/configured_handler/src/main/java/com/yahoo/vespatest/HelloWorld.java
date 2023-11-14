// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.vespatest.ResponseConfig;

/**
 * Vespa style JDisc handler only emitting a string defined in config.
 *
 * @author Steinar Knutsen
 */
public class HelloWorld extends AbstractRequestHandler {

    private final String response;

    public HelloWorld(ResponseConfig config) {
        this.response = config.response();
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write(response);
        writer.close();
        return null;
    }
}
