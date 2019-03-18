// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.async;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.container.AsyncResponse;
import javax.ws.rs.container.Suspended;
import java.lang.InterruptedException;
import java.lang.RuntimeException;

@Path("/")
public class AsyncResource {
    public static final long TIMEOUT_IN_MS = 10*1000;

    @GET
    @Path("/sync")
    public String syncGetWithTimeout() {
        return veryExpensiveOperation();
    }

    @GET
    @Path("/async")
    public void asyncGetWithTimeout(@Suspended final AsyncResponse asyncResponse) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                String result = veryExpensiveOperation();
                asyncResponse.resume(result);
            }
        }).start();
    }

    private String veryExpensiveOperation() {
        try {
            Thread.sleep(TIMEOUT_IN_MS);
        } catch (InterruptedException e) {
            throw new RuntimeException("Sleeping thread was interrupted.");
        }
        return "Slow response";
    }
}
