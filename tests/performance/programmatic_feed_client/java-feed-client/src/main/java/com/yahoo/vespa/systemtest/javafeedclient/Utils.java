// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import javax.net.ssl.HostnameVerifier;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.logging.LogManager;

import static java.nio.charset.StandardCharsets.UTF_8;

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
    static int connections() { return Integer.parseInt(System.getProperty("vespa.test.feed.connections")); }
    static String route() { return System.getProperty("vespa.test.feed.route"); }
    static URI endpoint() { return URI.create(System.getProperty("vespa.test.feed.endpoint")); }
    static int documents() { return Integer.parseInt(System.getProperty("vespa.test.feed.documents")); }
    static int maxConcurrentStreamsPerConnection() {
        return Integer.parseInt(System.getProperty("vespa.test.feed.max-concurrent-streams-per-connection"));
    }
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

}
