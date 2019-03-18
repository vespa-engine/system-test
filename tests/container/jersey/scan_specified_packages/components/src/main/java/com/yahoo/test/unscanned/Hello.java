// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.unscanned;

import javax.ws.rs.GET;
import javax.ws.rs.Path;

@Path("/unscanned")
public class Hello {

    @GET
    public String sayHello() {
        return "I should not have been scanned, so something went wrong!";
    }
}
