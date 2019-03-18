// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.scanned;

import javax.ws.rs.GET;
import javax.ws.rs.Path;

@Path("/scanned")
public class Hello {

    @GET
    public String sayHello() {
        return "I have been scanned, like I should!";
    }
}
