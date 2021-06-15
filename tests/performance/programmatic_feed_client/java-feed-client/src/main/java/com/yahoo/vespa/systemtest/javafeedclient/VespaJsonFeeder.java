// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.JsonFeeder;
import ai.vespa.feed.client.OperationStats;

import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.maxConcurrentStreamsPerConnection;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;
import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * @author jonmv
 */
public class VespaJsonFeeder {

    public static void main(String[] args) throws IOException {
        int documents = documents();
        String fieldsJson = fieldsJson();
        Path tmpFile = Files.createTempFile(null, null);
        try (Writer out = Files.newBufferedWriter(tmpFile, UTF_8)) {
            out.write("[");
            for (int i = 0; i < documents; i++)
                out.write(String.format("{\"put\":\"id:text:text::vespa-feed-client-%07d\",\"fields\": %s}%s",
                                        i, fieldsJson, i + 1 < documents ? "," : ""));
            out.write("]");
        }

        FeedClient client = Utils.createFeedClient();
        long start = System.nanoTime();
        CountDownLatch latch = new CountDownLatch(1);
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
        try (InputStream in = Files.newInputStream(tmpFile, StandardOpenOption.READ, StandardOpenOption.DELETE_ON_CLOSE);
             JsonFeeder feeder = JsonFeeder.builder(client).withRoute(route()).build()) {
            feeder.feedMany(in);
        }
        latch.countDown();
        Utils.printJsonReport(Duration.ofNanos(System.nanoTime() - start), client.stats(), "vespa-json-feeder");
    }

}
