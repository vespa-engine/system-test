// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.vespatest.ResponseConfig;

import java.util.logging.Logger;

/**
 * Vespa style JDisc handler only emitting a string defined in config.
 *
 * @author Steinar Knutsen
 */
public class HelloWorld extends AbstractRequestHandler {

    private static Logger log = Logger.getLogger(HelloWorld.class.getName());

    private final String response;

    public HelloWorld(ResponseConfig config) {
        String configResponse = null;
        try {
            // Triggers a NullPointerException due to uninitialized config parameter 'response'.
            configResponse = config.response();
            throw new RuntimeException("Did not get expected NPE due to uninitialized config parameter.");
        } catch (NullPointerException e) {
            log.info("Got expected NPE due to uninitialized config parameter.");
        }
        this.response = configResponse;
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write(response);
        writer.close();
        return null;
    }
}
