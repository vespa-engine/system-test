// Copyright Vespa.ai. All rights reserved.
package test;

import com.yahoo.jdisc.http.filter.DiscFilterResponse;
import com.yahoo.jdisc.http.filter.RequestView;
import com.yahoo.jdisc.http.filter.SecurityResponseFilter;

/**
 * Response filter that adds observed port as response header
 *
 * @author bjorncs
 */
public class HostHeaderResponseFilter implements SecurityResponseFilter {
    @Override
    public void filter(DiscFilterResponse response, RequestView request) {
        response.addHeader("Response-Filter-Observed-Port", Integer.toString(request.getUri().getPort()));
    }
}
