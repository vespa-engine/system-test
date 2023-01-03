// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.OperationParameters;
import ai.vespa.feed.client.OperationStats;

import java.io.IOException;
import java.time.Duration;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.benchmarkSeconds;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.createFeedClient;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.gzipRequests;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.printJsonReport;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.warmupSeconds;

/**
 * @author bjorncs
 */
public class VespaFeedClient {
    public static void main(String[] args) throws IOException {
        String fieldsJson = fieldsJson();
        FeedClient client = createFeedClient();
        AtomicReference<OperationStats> stats = new AtomicReference<>();
        ScheduledExecutorService executor = Executors.newScheduledThreadPool(1);
        executor.schedule(() -> { stats.set(client.stats()); },
                          warmupSeconds(), TimeUnit.SECONDS);
        executor.schedule(() -> { stats.set(client.stats().since(stats.get())); executor.shutdown(); },
                          warmupSeconds() + benchmarkSeconds(), TimeUnit.SECONDS);
        executor.scheduleAtFixedRate(() -> { System.err.println(client.stats()); },
                                     1, 1, TimeUnit.SECONDS);
        try (client) {
            while ( ! executor.isShutdown()) {
                DocumentId id = DocumentId.of("text", "text", String.format("vespa-feed-client-%07d", + (int) (Math.random() * 1e6)));
                client.put(id, "{\"fields\": " + fieldsJson + "}", OperationParameters.empty().route(route()))
                      .whenComplete((result, error) -> {
                          if (error != null) {
                              System.err.println("For id " + id + ": " + error);
                          }
                      });
            }
        }
        printJsonReport(Duration.ofSeconds(benchmarkSeconds()), stats.get(), "vespa-feed-client" + (gzipRequests() ? "-gzip" : ""));
    }

}
