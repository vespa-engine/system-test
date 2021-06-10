// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.systemtest.javafeedclient;

import com.yahoo.vespa.http.client.FeedClient;
import com.yahoo.vespa.http.client.FeedClientFactory;
import com.yahoo.vespa.http.client.config.Cluster;
import com.yahoo.vespa.http.client.config.ConnectionParams;
import com.yahoo.vespa.http.client.config.Endpoint;
import com.yahoo.vespa.http.client.config.FeedParams;
import com.yahoo.vespa.http.client.config.SessionParams;

import java.io.IOException;
import java.net.URI;
import java.util.concurrent.CountDownLatch;

import static com.yahoo.vespa.systemtest.javafeedclient.Utils.TRUST_ALL_VERIFIER;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.caCertificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.certificate;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.connections;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.fieldsJson;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.documents;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.endpoint;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.privateKey;
import static com.yahoo.vespa.systemtest.javafeedclient.Utils.route;

/**
 * @author bjorncs
 */
public class VespaHttpClient {
    public static void main(String[] args) throws IOException, InterruptedException {
        URI endpoint = endpoint();
        SessionParams sessionParams = new SessionParams.Builder()
                .setFeedParams(new FeedParams.Builder()
                        .setRoute(route())
                        .build())
                .setConnectionParams(new ConnectionParams.Builder()
                        .setCaCertificates(caCertificate())
                        .setCertificateAndPrivateKey(privateKey(), certificate())
                        .setNumPersistentConnectionsPerEndpoint(connections())
                        .setHostnameVerifier(TRUST_ALL_VERIFIER)
                        .build())
                .addCluster(new Cluster.Builder()
                        .addEndpoint(Endpoint.create(endpoint.getHost(), endpoint.getPort(), true))
                        .build())
                .build();
        int documents = documents();
        String fieldsJson = fieldsJson();

        CountDownLatch doneSignal = new CountDownLatch(documents);
        BenchmarkReporter reporter = new BenchmarkReporter("vespa-http-client");
        FeedClient feedClient = FeedClientFactory.create(sessionParams, (docId, documentResult) -> {
            if (documentResult.isSuccess()) {
                reporter.incrementSuccess();
            } else {
                reporter.incrementFailure();
                System.out.println(documentResult + "\n" + documentResult.getDetails());
            }
            doneSignal.countDown();
        });
        try {
            for (int i = 0; i < documents; i++) {
                String docId = String.format("id:text:text::vespa-http-client-%07d", i);
                String operationJson = "{\"put\": \"" + docId + "\", \"fields\": " + fieldsJson + "}";
                feedClient.stream(docId, operationJson);
            }
            doneSignal.await();
        } finally {
            feedClient.close();
        }
        reporter.printJsonReport();
    }
}
