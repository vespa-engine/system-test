// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.processing.*;
import com.yahoo.processing.execution.Execution;
import com.yahoo.processing.response.AbstractData;

public class ProcessorTwo extends Processor {

    @Override
    public Response process(Request request, Execution execution) {
        Response response = execution.process(request);
        response.data().add(new StringData(request, "No, make that two!"));
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
