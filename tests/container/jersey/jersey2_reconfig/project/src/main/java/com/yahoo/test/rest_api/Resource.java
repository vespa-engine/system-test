// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.rest_api;

import com.yahoo.test.InjectedComponent;
import com.yahoo.container.jaxrs.annotation.Component;
import javax.ws.rs.GET;
import javax.ws.rs.Path;

@Path("/hello")
public class Resource {
    private final String message;

    public Resource(@Component InjectedComponent injectedComponent) {
        message = injectedComponent.message;
    }

    @GET
    public String sayHello() {
        return message;
    }
}
