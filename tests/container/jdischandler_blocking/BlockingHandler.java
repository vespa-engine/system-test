// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.handler.*;

import java.nio.ByteBuffer;

public class BlockingHandler extends AbstractRequestHandler {

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter out = ResponseDispatch.newInstance(200).connectFastWriter(handler);
        out.write("BLOCKED!");
        out.close();
        request.refer(); // retain a reference, blocking shutdown
        return null;
    }
}
