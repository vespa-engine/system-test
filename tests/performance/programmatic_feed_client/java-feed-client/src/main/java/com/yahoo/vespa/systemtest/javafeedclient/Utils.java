// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import javax.net.ssl.HostnameVerifier;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * @author bjorncs
 */
class Utils {

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

}
