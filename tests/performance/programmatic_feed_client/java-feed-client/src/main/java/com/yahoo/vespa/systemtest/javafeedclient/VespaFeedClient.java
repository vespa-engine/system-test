// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.OperationParameters;
import ai.vespa.feed.client.OperationStats;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.createFeedClient;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.maxConcurrentStreamsPerConnection;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.printJsonReport;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;

/**
 * @author bjorncs
 */
public class VespaFeedClient {
    public static void main(String[] args) throws IOException {
        int documents = documents();
        String fieldsJson = fieldsJson();
        FeedClient client = createFeedClient();
        CountDownLatch latch = new CountDownLatch(1);
        long start = System.nanoTime();
        new Thread(() -> {
            try {
                while ( ! latch.await(1000, TimeUnit.MILLISECONDS)) {
                    OperationStats stats = client.stats();
                    System.err.printf("successes:  %7d  exceptions: %7d  failures:   %7d  inflight:   %7d\n",
                                      stats.successes(), stats.exceptions(), stats.responses() - stats.successes(), stats.inflight());
                }
            }
            catch (InterruptedException ignored) { }
        }).start();
        try (client) {
            for (int i = 0; i < documents; i++) {
                DocumentId id = DocumentId.of("text", "text", String.format("vespa-feed-client-%07d", + i));
                client.put(id, "{\"fields\": " + fieldsJson + "}", OperationParameters.empty().route(route()))
                      .whenComplete((result, error) -> {
                          if (error != null) {
                              System.err.println("For id " + id + ": " + error);
                          }
                      });
            }
        }
        latch.countDown();
        printJsonReport(Duration.ofNanos(System.nanoTime() - start), client.stats(), "vespa-feed-client");
    }

}
