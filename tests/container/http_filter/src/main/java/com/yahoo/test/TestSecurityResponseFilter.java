// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
