// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.ContentChannel;
import com.yahoo.jdisc.handler.ReadableContentChannel;
import com.yahoo.jdisc.handler.RequestDispatch;
import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.handler.ThreadedRequestHandler;
import com.yahoo.text.Utf8;

import java.net.URI;
import java.nio.ByteBuffer;
import java.util.concurrent.Executors;

/**
 * @author gv
 */
public class DispatchHandler extends ThreadedRequestHandler {

    public DispatchHandler() {
        super(Executors.newFixedThreadPool(4));
    }

    @Override
    protected void handleRequest(final Request parent,
                                 ReadableContentChannel requestContent,
                                 final ResponseHandler handler) {
        new RequestDispatch() {
            @Override
            protected Request newRequest() {
                return new Request(parent, URI.create("http://remotehost/"));
            }
            @Override
            public ContentChannel handleResponse(Response response) {
                ContentChannel content = handler.handleResponse(response);
                content.write(ByteBuffer.wrap(Utf8.toBytes("Response handled by DispatchHandler.\n")), null);
                return content;
            }
        }.dispatch();

        // Drain the request content, otherwise completion handlers will not be called.
        while (requestContent.read() != null);
    }
}
