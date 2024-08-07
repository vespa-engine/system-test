// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.processing.*;
import com.yahoo.processing.execution.Execution;

public class NopProcessor extends Processor {

    @Override
    public Response process(Request request, Execution execution) {
        return execution.process(request);
    }
}
