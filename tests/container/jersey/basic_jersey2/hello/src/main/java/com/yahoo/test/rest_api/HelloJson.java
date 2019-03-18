// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.rest_api;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.xml.bind.annotation.XmlRootElement;
import com.fasterxml.jackson.annotation.JsonProperty;

@Path("/json")
public class HelloJson {

    @GET
    @Produces("application/json")
    public Hello sayHello() {
        return new Hello();
    }

    public static class Hello {
        public final String message = "Hello JSON!";

        @JsonProperty("JsonProperty Integer")
        public final int someInt = 3;
    }
}
