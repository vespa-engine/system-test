// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.processing.*;
import com.yahoo.processing.execution.Execution;

public class NopProcessor extends Processor {

    @Override
    public Response process(Request request, Execution execution) {
        return execution.process(request);
    }
}
