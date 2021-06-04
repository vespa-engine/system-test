// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.FeedClientBuilder;
import ai.vespa.feed.client.OperationParameters;

import java.io.IOException;
import java.util.concurrent.CountDownLatch;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.TRUST_ALL_VERIFIER;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.caCertificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.certificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.endpoint;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.maxConcurrentStreamsPerConnection;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.privateKey;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;

/**
 * @author bjorncs
 */
public class VespaFeedClient {
    public static void main(String[] args) throws IOException, InterruptedException {
        int documents = documents();
        CountDownLatch doneSignal = new CountDownLatch(documents);
        BenchmarkReporter reporter = new BenchmarkReporter("vespa-feed-client");
        try (FeedClient client = createFeedClient()) {
            for (int i = 0; i < documents; i++) {
                DocumentId id = DocumentId.of("music", "music", "vespa-feed-client-" + i);
                client.put(id, "{\"fields\": {\"title\": \"vespa.ai\"}}", OperationParameters.empty().route(route()))
                        .whenComplete((result, error) -> {
                            if (error != null) {
                                reporter.incrementFailure();
                                System.out.println("For id " + id + ": " + error);
                            } else {
                                reporter.incrementSuccess();
                            }
                            doneSignal.countDown();
                        });
            }
            doneSignal.await();
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
