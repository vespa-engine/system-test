// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.jersey_main;

import javax.ws.rs.GET;
import javax.ws.rs.Path;

@Path("/hello1")
public class Resource1 {

    @GET
    public String sayHello() {
        return "Hello from resource 1";
    }
}
