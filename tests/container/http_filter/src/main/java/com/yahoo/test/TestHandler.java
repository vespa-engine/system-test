// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.AbstractRequestHandler;
import com.yahoo.jdisc.handler.ContentChannel;
import com.yahoo.jdisc.handler.FastContentWriter;
import com.yahoo.jdisc.handler.ResponseDispatch;
import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.http.HttpResponse;

/**
 * @author tonyv
 */
public class TestHandler extends AbstractRequestHandler {
    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler responseHandler) {
        FastContentWriter contentWriter = ResponseDispatch.newInstance(HttpResponse.newInstance(Response.Status.OK)).connectFastWriter(responseHandler);
        contentWriter.write("TestFilterHandler: ");
        if (request.context().containsKey(TestRequestFilter.headerName))
            contentWriter.write(TestRequestFilter.headerName);
        contentWriter.close();
        return null;
    }
}
