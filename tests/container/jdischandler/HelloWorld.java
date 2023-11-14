// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

/**
 * Minimal Vespa style JDisc handler only emitting a constant string.
 *
 * @author Steinar Knutsen
 */
public class HelloWorld extends AbstractRequestHandler {

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("Hello, world!");
        writer.close();
        return null;
    }
}
