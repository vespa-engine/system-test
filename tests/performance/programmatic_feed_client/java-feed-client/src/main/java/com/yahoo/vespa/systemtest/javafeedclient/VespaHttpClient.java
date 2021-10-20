// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.yahoo.vespa.http.client.FeedClient;
import com.yahoo.vespa.http.client.FeedClientFactory;
import com.yahoo.vespa.http.client.config.SessionParams;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.benchmarkSeconds;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.warmupSeconds;

/**
 * @author bjorncs
 */
public class VespaHttpClient {

    public static void main(String[] args) throws IOException {
        SessionParams sessionParams = Utils.createSessionParams();
        String fieldsJson = fieldsJson();
        Instant start = Instant.now();

        BenchmarkReporter reporter = new BenchmarkReporter("vespa-http-client");
        FeedClient feedClient = FeedClientFactory.create(sessionParams, (docId, documentResult) -> {
            if (Instant.now().isBefore(start.plusSeconds(warmupSeconds()))) return;
            if (Instant.now().isAfter(start.plusSeconds(warmupSeconds() + benchmarkSeconds()))) return;
            if (documentResult.isSuccess()) {
                reporter.incrementSuccess();
            } else {
                reporter.incrementFailure();
                System.err.println(documentResult + "\n" + documentResult.getDetails());
            }
        });
        try (feedClient) {
            while (Instant.now().isBefore(start.plusSeconds(warmupSeconds() + benchmarkSeconds()))) {
                String docId = String.format("id:text:text::vespa-http-client-%07d", (int) (Math.random() * 1e6));
                String operationJson = "{\"put\": \"" + docId + "\", \"fields\": " + fieldsJson + "}";
                feedClient.stream(docId, operationJson);
            }
        }
        reporter.printJsonReport(Duration.ofSeconds(benchmarkSeconds()));
    }

}
