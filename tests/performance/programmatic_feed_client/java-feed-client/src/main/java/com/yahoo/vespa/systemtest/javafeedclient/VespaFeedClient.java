// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.FeedClientBuilder;
import ai.vespa.feed.client.OperationParameters;
import ai.vespa.feed.client.OperationStats;
import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import java.io.IOException;
import java.time.Duration;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.TRUST_ALL_VERIFIER;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.caCertificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.certificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.endpoint;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.maxConcurrentStreamsPerConnection;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.privateKey;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;

/**
 * @author bjorncs
 */
public class VespaFeedClient {
    public static void main(String[] args) throws IOException {
        int documents = documents();
        String fieldsJson = fieldsJson();
        FeedClient client = createFeedClient();
        long start = System.nanoTime();
        try (client) {
            for (int i = 0; i < documents; i++) {
                DocumentId id = DocumentId.of("text", "text", String.format("vespa-feed-client-%07d", + i));
                client.put(id, "{\"fields\": " + fieldsJson + "}", OperationParameters.empty().route(route()))
                      .whenComplete((result, error) -> {
                          if (error != null) {
                              System.out.println("For id " + id + ": " + error);
                          }
                      });
            }
        }
        printJsonReport(Duration.ofNanos(System.nanoTime() - start), client.stats());
    }

    static void printJsonReport(Duration duration, OperationStats stats) throws IOException {
        JsonFactory factory = new JsonFactory();
        long successes = stats.responsesByCode().get(200);
        try (JsonGenerator generator = factory.createGenerator(System.out)) {
            generator.writeStartObject();
            generator.writeNumberField("feeder.runtime", duration.toMillis());
            generator.writeNumberField("feeder.okcount", successes);
            generator.writeNumberField("feeder.errorcount", stats.requests() - successes);
            generator.writeNumberField("feeder.exceptions", stats.exceptions());
            generator.writeNumberField("feeder.bytessent", stats.bytesSent());
            generator.writeNumberField("feeder.bytesreceived", stats.bytesReceived());
            generator.writeNumberField("feeder.throughput", successes / (double) duration.toMillis() * 1000);
            generator.writeNumberField("feeder.minlatency", stats.minLatencyMillis());
            generator.writeNumberField("feeder.avglatency", stats.averageLatencyMillis());
            generator.writeNumberField("feeder.maxlatency", stats.maxLatencyMillis());
            generator.writeStringField("loadgiver", "vespa-feed-client");
            generator.writeEndObject();
            generator.flush();
        }
    }

    private static FeedClient createFeedClient() {
        int connections = Utils.connections();
        return FeedClientBuilder.create(endpoint())
                .setMaxStreamPerConnection(maxConcurrentStreamsPerConnection())
                .setConnectionsPerEndpoint(connections)
                .setCaCertificates(caCertificate())
                .setCertificate(certificate(), privateKey())
                .setHostnameVerifier(TRUST_ALL_VERIFIER)
                .build();
    }
}
