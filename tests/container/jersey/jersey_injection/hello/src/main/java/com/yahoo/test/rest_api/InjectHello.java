// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.rest_api;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import com.yahoo.test.HelloBase;
import com.yahoo.container.jaxrs.annotation.Component;

@Path("/hello")
public class InjectHello {

    private final HelloBase hello;

    public InjectHello(@Component HelloBase hello) {
        this.hello = hello;
    }

    @GET
    @Produces("application/json")
    public Response sayHello() {
        return new Response(System.identityHashCode(this), hello.idHashCode());
    }

    public static class Response {
        public final int resourceId;
        public final int injectedId;

        public Response(int resourceId, int injectedId) {
            this.resourceId = resourceId;
            this.injectedId = injectedId;
        }
    }
}
