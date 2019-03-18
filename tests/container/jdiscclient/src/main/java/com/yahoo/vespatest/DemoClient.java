// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.nio.ByteBuffer;
import java.util.logging.Logger;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.ContentChannel;
import com.yahoo.jdisc.handler.ResponseDispatch;
import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.service.AbstractClientProvider;
import com.yahoo.log.LogLevel;
import com.yahoo.text.Utf8;

/**
 * Dummy client which only responds with a configured payload.
 *
 * @author Steinar Knutsen
 */
public class DemoClient extends AbstractClientProvider {
    private final Logger logger = Logger.getLogger(DemoClient.class.getName());
    private final byte[] response;
    private static final byte[] error = Utf8.toBytes("Internal error. Check the log.");
    private boolean started = false;

    public DemoClient(ResponseConfig config) {
        this.response = Utf8.toBytes(config.response());
    }

    @Override
    public void start() {
        if (started) {
            logger.log(LogLevel.ERROR, "DemoClient.start() invoked more than once");
        } else {
            started = true;
        }
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        if (!started) {
            logger.log(LogLevel.ERROR, "DemoClient received a request before start() was invoked.");
            ResponseDispatch.newInstance(Response.Status.INTERNAL_SERVER_ERROR, ByteBuffer.wrap(error)).dispatch(handler);
        } else {
            ResponseDispatch.newInstance(Response.Status.OK, ByteBuffer.wrap(response)).dispatch(handler);
        }
        return null;
    }
}
