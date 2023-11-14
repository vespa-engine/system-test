// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.handler;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.test.component.*;


public class HandlerTakingComponent extends AbstractRequestHandler {
    private final String response;

    public HandlerTakingComponent(GenericComponent component) {
        this.response = this.getClass().getSimpleName() + " got " + component.message;
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write(response);
        writer.close();
        return null;
    }
}
