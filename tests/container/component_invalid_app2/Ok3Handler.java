// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

public class Ok3Handler extends AbstractRequestHandler {

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("Ok3");
        writer.close();
        return null;
    }
}
