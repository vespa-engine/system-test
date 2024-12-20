// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.test.ResponseConfig;

public class Ok1Handler extends AbstractRequestHandler {

    private final String response;

    public Ok1Handler(ResponseConfig config) {
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
