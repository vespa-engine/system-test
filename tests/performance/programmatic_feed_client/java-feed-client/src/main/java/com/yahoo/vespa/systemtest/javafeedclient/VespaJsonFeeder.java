// Copyright Vespa.ai. All rights reserved.
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
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.printJsonReport;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.warmupSeconds;
import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * @author Jon Marius Venstad
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
        AtomicReference<OperationStats> stats = new AtomicReference<>();
        AtomicLong startNanos = new AtomicLong();
        ScheduledExecutorService executor = Executors.newScheduledThreadPool(1);
        executor.schedule(() -> { stats.set(client.stats()); startNanos.set(System.nanoTime()); },
                          warmupSeconds(), TimeUnit.SECONDS);
        executor.scheduleAtFixedRate(() -> { System.err.println(client.stats()); },
                                     1, 1, TimeUnit.SECONDS);

        try (InputStream in = Files.newInputStream(tmpFile, StandardOpenOption.READ, StandardOpenOption.DELETE_ON_CLOSE);
             JsonFeeder feeder = JsonFeeder.builder(client).withRoute(route()).build()) {
            feeder.feedMany(in);
        }
        printJsonReport(Duration.ofNanos(System.nanoTime() - startNanos.get()), client.stats().since(stats.get()), "vespa-json-feeder");
        executor.shutdown();
    }

}
