// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.http.filter.DiscFilterResponse;
import com.yahoo.jdisc.http.filter.SecurityResponseFilter;
import com.yahoo.jdisc.http.filter.RequestView;

/**
 * @author tonyv
 */
public class TestSecurityResponseFilter implements SecurityResponseFilter {

    @Override
    public void filter(DiscFilterResponse response, RequestView request) {
        response.setHeaders("X-TestSecurityResponseFilter", "true");
    }
}
