// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * @author bjorncs
 */
class BenchmarkReporter {

    private final String clientName;
    private final AtomicInteger successfulRequests = new AtomicInteger(0);
    private final AtomicInteger failedRequests = new AtomicInteger(0);

    BenchmarkReporter(String clientName) {
        this.clientName = clientName;
    }

    void incrementSuccess() { successfulRequests.incrementAndGet(); }
    void incrementFailure() { failedRequests.incrementAndGet(); }

    void printJsonReport(Duration duration) throws IOException {
        JsonFactory factory = new JsonFactory();
        try (JsonGenerator generator = factory.createGenerator(System.out)) {
            generator.writeStartObject();
            generator.writeNumberField("feeder.runtime", duration.toMillis());
            generator.writeNumberField("feeder.okcount", successfulRequests.get());
            generator.writeNumberField("feeder.errorcount", failedRequests.get());
            generator.writeNumberField("feeder.throughput", successfulRequests.get() / (double)duration.toMillis() * 1000);
            generator.writeStringField("loadgiver", clientName);
            generator.writeEndObject();
            generator.flush();
        }
    }

}
