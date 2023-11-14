// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;
import com.yahoo.jdisc.http.HttpResponse;

/**
 * Handler that returns observed host header and port
 *
 * @author bjorncs
 */
public class HostHeaderHandler extends AbstractRequestHandler {

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        try (FastContentWriter writer = ResponseDispatch.newInstance(new ResponseWithHeaders(request)).connectFastWriter(handler)) {
            writer.write("OK");
        }
        return null;
    }

    private static class ResponseWithHeaders extends HttpResponse {
        ResponseWithHeaders(Request request) {
            super(request, Response.Status.OK, null, null);
            headers().add("Observed-Host-Header", request.headers().getFirst("Host"));
            headers().add("Handler-Observed-Port", Integer.toString(request.getUri().getPort()));
            headers().add("Request-Filter-Observed-Port", request.context().get("Request-Filter-Observed-Port").toString());
        }
    }

}
