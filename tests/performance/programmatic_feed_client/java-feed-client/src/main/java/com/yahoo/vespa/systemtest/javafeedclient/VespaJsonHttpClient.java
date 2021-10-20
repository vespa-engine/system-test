// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.yahoo.vespa.http.client.FeedClient;
import com.yahoo.vespa.http.client.FeedClientFactory;
import com.yahoo.vespa.http.client.config.SessionParams;
import com.yahoo.vespa.http.client.runner.Runner;

import java.io.IOException;
import java.io.InputStream;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.benchmarkSeconds;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.warmupSeconds;
import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * @author jonmv
 */
public class VespaJsonHttpClient {

    public static void main(String[] args) throws IOException {
        int documents = documents();
        String fieldsJson = fieldsJson();
        if (fieldsJson.length() > 2000) documents /= 20;
        Path tmpFile = Files.createTempFile(null, null);
        try (Writer out = Files.newBufferedWriter(tmpFile, UTF_8)) {
            out.write("[");
            for (int i = 0; i < documents; i++)
                out.write(String.format("{\"put\":\"id:text:text::vespa-http-client-%07d\",\"fields\": %s}%s",
                                        i, fieldsJson, i + 1 < documents ? "," : ""));
            out.write("]");
        }

        SessionParams sessionParams = Utils.createSessionParams();
        Instant start = Instant.now();
        Instant end = start.plusSeconds(warmupSeconds()).plusSeconds(benchmarkSeconds());

        BenchmarkReporter reporter = new BenchmarkReporter("vespa-json-http-client");
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
        try (feedClient;
             InputStream in = Files.newInputStream(tmpFile, StandardOpenOption.READ, StandardOpenOption.DELETE_ON_CLOSE)) {
            Runner.send(feedClient, in, true, new AtomicInteger(), false);
        }
        if (Instant.now().isBefore(end)) end = Instant.now();

        reporter.printJsonReport(Duration.between(start.plusSeconds(warmupSeconds()), end));
    }

}
