// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.http.filter.DiscFilterRequest;
import com.yahoo.jdisc.http.filter.SecurityRequestFilter;

/**
 * Response filter that adds port as request attribute. This attribute is forwarded as a response header in the request handler.
 *
 * @author bjorncs
 */
public class HostHeaderRequestFilter implements SecurityRequestFilter {
    @Override
    public void filter(DiscFilterRequest request, ResponseHandler handler) {
        request.setAttribute("Request-Filter-Observed-Port", Integer.toString(request.getUri().getPort()));
    }
}
