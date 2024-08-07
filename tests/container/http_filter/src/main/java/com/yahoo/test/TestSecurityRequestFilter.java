// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.ContentChannel;
import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.http.HttpResponse;
import com.yahoo.jdisc.http.filter.DiscFilterRequest;
import com.yahoo.jdisc.http.filter.SecurityRequestFilter;

import java.nio.ByteBuffer;

/**
 * @author tonyv
 */
public class TestSecurityRequestFilter implements SecurityRequestFilter {
    @Override
    public void filter(DiscFilterRequest request, ResponseHandler responseHandler) {
        HttpResponse response = HttpResponse.newInstance(Response.Status.FORBIDDEN);
        ContentChannel channel = responseHandler.handleResponse(response);
        channel.write(ByteBuffer.wrap("Forbidden by TestSecurityRequestFilter".getBytes()), null);
        channel.close(null);
    }
}
