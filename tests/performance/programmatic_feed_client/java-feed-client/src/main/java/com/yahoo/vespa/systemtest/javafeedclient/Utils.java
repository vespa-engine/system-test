// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import java.io.IOException;
import java.time.Duration;

/**
 * @author bjorncs
 */
class Utils {
    private Utils() {}

    static void printBenchmarkResult(String clientName, Duration duration, int successfulRequests, int failedRequests) throws IOException {
        JsonFactory factory = new JsonFactory();
        try (JsonGenerator generator = factory.createGenerator(System.out)) {
            generator.writeStartObject();
            generator.writeNumberField("feeder.runtime", duration.toMillis());
            generator.writeNumberField("feeder.okcount", successfulRequests);
            generator.writeNumberField("feeder.errorcount", failedRequests);
            generator.writeNumberField("feeder.throughput", successfulRequests / (double)duration.toMillis() * 1000);
            generator.writeStringField("loadgiver", clientName);
            generator.writeEndObject();
            generator.flush();
        }
    }
}
