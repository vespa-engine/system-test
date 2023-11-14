// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.jdisc.AbstractResource;
import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.http.filter.ResponseFilter;

/**
 * @author tonyv
 */
public class TestResponseFilter extends AbstractResource implements ResponseFilter {
    @Override
    public void filter(Response response, Request request) {
        response.headers().add("X-TestResponseFilter", "true");
    }
}
