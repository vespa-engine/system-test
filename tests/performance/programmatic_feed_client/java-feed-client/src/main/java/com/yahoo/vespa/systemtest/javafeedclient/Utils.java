// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespa.systemtest.javafeedclient;

import ai.vespa.feed.client.FeedClient;
import ai.vespa.feed.client.FeedClientBuilder;
import ai.vespa.feed.client.FeedClientBuilder.Compression;
import ai.vespa.feed.client.OperationStats;
import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import javax.net.ssl.HostnameVerifier;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.Map.Entry;
import java.util.Optional;
import java.util.logging.LogManager;

import static ai.vespa.feed.client.FeedClientBuilder.Compression.auto;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.Objects.requireNonNullElse;

/**
 * @author bjorncs
 */
class Utils {

    static {
        // Disable java.util.logging
        LogManager.getLogManager().reset();
    }

    static final HostnameVerifier TRUST_ALL_VERIFIER = (hostname, session) -> true;

    private Utils() {}

    static Path certificate() { return Paths.get(System.getProperty("vespa.test.feed.certificate")); }
    static Path privateKey() { return Paths.get(System.getProperty("vespa.test.feed.private-key")); }
    static Path caCertificate() { return Paths.get(System.getProperty("vespa.test.feed.ca-certificate")); }
    static String route() { return System.getProperty("vespa.test.feed.route"); }
    static URI endpoint() { return URI.create(System.getProperty("vespa.test.feed.endpoint")); }
    static int documents() { return Integer.parseInt(System.getProperty("vespa.test.feed.documents")); }
    static int warmupSeconds() { return Integer.parseInt(System.getProperty("vespa.test.feed.warmup.seconds")); }
    static int benchmarkSeconds() { return Integer.parseInt(System.getProperty("vespa.test.feed.benchmark.seconds")); }
    static Compression compression() { return Optional.ofNullable(System.getProperty("vespa.test.feed.compression")).map(Compression::valueOf).orElse(null); }
    static String fieldsJson() throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (JsonGenerator generator = new JsonFactory().createGenerator(out)) {
            generator.writeStartObject();
            generator.writeStringField("text", System.getProperty("vespa.test.feed.document-text"));
            generator.writeEndObject();
            generator.flush();
        }
        return out.toString(UTF_8);
    }

    static void printJsonReport(Duration duration, OperationStats stats, String loadgiver) throws IOException {
        printJsonReport(duration, stats, loadgiver, System.out);
    }

    static void printJsonReport(Duration duration, OperationStats stats, String loadgiver, OutputStream out) throws IOException {
        JsonFactory factory = new JsonFactory();
        try (JsonGenerator generator = factory.createGenerator(out)) {
            generator.writeStartObject();
            generator.writeNumberField("feeder.runtime", duration.toMillis());
            generator.writeNumberField("feeder.okcount", stats.successes());
            generator.writeNumberField("feeder.errorcount", stats.exceptions() + stats.statsByCode().entrySet().stream()
                    .filter(entry -> entry.getKey() != 200)
                    .map(e -> e.getValue().count())
                    .reduce(0L, Long::sum));
            generator.writeNumberField("feeder.exceptions", stats.exceptions());
            generator.writeNumberField("feeder.bytessent", stats.bytesSent());
            generator.writeNumberField("feeder.bytesreceived", stats.bytesReceived());
            generator.writeNumberField("feeder.throughput", stats.successes() / (double) duration.toMillis() * 1000);
            generator.writeNumberField("feeder.minlatency", stats.minLatencyMillis());
            generator.writeNumberField("feeder.avglatency", stats.averageLatencyMillis());
            generator.writeNumberField("feeder.maxlatency", stats.maxLatencyMillis());
            generator.writeStringField("loadgiver", loadgiver);
            generator.writeEndObject();
            generator.flush();
        }
    }

    static FeedClient createFeedClient() {
        return FeedClientBuilder.create(endpoint())
                                .setCaCertificatesFile(caCertificate())
                                .setCertificate(certificate(), privateKey())
                                .setHostnameVerifier(TRUST_ALL_VERIFIER)
                                .setCompression(requireNonNullElse(compression(), auto))
                                .build();
    }

}
