// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.jdisc.AbstractResource;
import com.yahoo.jdisc.handler.ResponseHandler;
import com.yahoo.jdisc.http.HttpRequest;
import com.yahoo.jdisc.http.filter.RequestFilter;

/**
 * @author tonyv
 */
public class TestRequestFilter extends AbstractResource implements RequestFilter  {
    public static final String headerName = "TestRequestFilter";

    @Override
    public void filter(HttpRequest httpRequest, ResponseHandler responseHandler) {

        httpRequest.context().put(headerName, "true");
    }
}
