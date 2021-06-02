// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.FeedClientBuilder;
import ai.vespa.feed.client.OperationParameters;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.printBenchmarkResult;

/**
 * @author bjorncs
 */
public class VespaFeedClient {
    public static void main(String[] args) throws IOException, InterruptedException {
        String route = System.getProperty("vespa.test.feed.route");
        int documents = Integer.parseInt(System.getProperty("vespa.test.feed.documents"));
        AtomicInteger successfulRequests = new AtomicInteger(0);
        AtomicInteger failedRequests = new AtomicInteger(0);
        CountDownLatch doneSignal = new CountDownLatch(documents);
        long start = System.nanoTime();
        try (FeedClient client = createFeedClient()) {
            for (int i = 0; i < documents; i++) {
                DocumentId id = DocumentId.of("music", "music", Integer.toString(i));
                client.put(id, "{\"fields\": {\"title\": \"Ronny och Ragge\"}}", OperationParameters.empty().route(route))
                        .whenComplete((result, error) -> {
                            if (result != null) {
                                successfulRequests.incrementAndGet();
                            } else {
                                failedRequests.incrementAndGet();
                            }
                            doneSignal.countDown();
                        });
            }
            doneSignal.await();
        }
        Duration duration = Duration.ofNanos(System.nanoTime() - start);
        printBenchmarkResult("vespa-feed-client", duration, successfulRequests.get(), failedRequests.get());
    }

    private static FeedClient createFeedClient() {
        Path certificate = Paths.get(System.getProperty("vespa.test.feed.certificate"));
        Path privateKey = Paths.get(System.getProperty("vespa.test.feed.private-key"));
        Path caCertificate = Paths.get(System.getProperty("vespa.test.feed.ca-certificate"));
        URI endpoint = URI.create(System.getProperty("vespa.test.feed.endpoint"));
        int maxConcurrentStreamsPerConnection = Integer.parseInt(
                System.getProperty("vespa.test.feed.max-concurrent-streams-per-connection"));
        int connections = Integer.parseInt(System.getProperty("vespa.test.feed.connections"));
        return FeedClientBuilder.create(endpoint)
                .setMaxStreamPerConnection(maxConcurrentStreamsPerConnection)
                .setMaxConnections(connections)
                .setCaCertificates(caCertificate)
                .setCertificate(certificate, privateKey)
                .setHostnameVerifier((hostname, session) -> true)
                .build();
    }
}
