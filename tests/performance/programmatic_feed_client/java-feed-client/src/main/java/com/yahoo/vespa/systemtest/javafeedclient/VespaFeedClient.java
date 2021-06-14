// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.DocumentId;
import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.OperationParameters;

import java.io.IOException;
import java.time.Duration;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.createFeedClient;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
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
        printJsonReport(Duration.ofNanos(System.nanoTime() - start), client.stats(), "vespa-feed-client");
    }

}
