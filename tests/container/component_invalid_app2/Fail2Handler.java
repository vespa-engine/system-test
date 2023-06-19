// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import java.util.List;
import java.util.ArrayList;
import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

public class Fail2Handler extends AbstractRequestHandler {

    public Fail2Handler() {
        String nullString = null;
        System.out.println("This will throw a NullPointerException: " + nullString.length());
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("Fail2");
        writer.close();
        return null;
    }
}
