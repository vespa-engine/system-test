// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.processing.*;
import com.yahoo.processing.execution.Execution;
import com.yahoo.processing.response.AbstractData;

public class HelloWorld extends Processor {

    @Override
    public Response process(Request request, Execution execution) {
        Response response = execution.process(request);
        response.data().add(new StringData(request, "Hello, world!"));
        return response;
    }

    private static class StringData extends AbstractData {

        private String value;

        public StringData(Request request, String value) {
            super(request);
            this.value = value;
        }

        @Override
        public String toString() {
            return value;
        }
    }
}
