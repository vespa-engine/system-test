// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.config;

import com.yahoo.config.subscription.ConfigTester;
import com.yahoo.jrt.Request;
import com.yahoo.jrt.Supervisor;
import com.yahoo.jrt.Target;
import com.yahoo.jrt.Transport;
import com.yahoo.jrt.Values;
import com.yahoo.vespa.config.protocol.CompressionType;
import com.yahoo.vespa.config.protocol.DefContent;
import com.yahoo.vespa.config.protocol.JRTClientConfigRequest;
import com.yahoo.vespa.config.protocol.JRTClientConfigRequestV3;
import com.yahoo.vespa.config.protocol.Trace;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.Test;

import java.util.Collections;
import java.util.Optional;

import static com.yahoo.vespa.config.ErrorCode.ILLEGAL_CONFIG_MD5;
import static com.yahoo.vespa.config.PayloadChecksum.Type.MD5;
import static com.yahoo.vespa.config.PayloadChecksum.Type.XXHASH64;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/**
 * Tests for different client requests to config server.
 *
 * @author Harald Musum
 */
public class ConfigClientTest {

    public static final String DEF_NAME = "app";

    // getConfig parameters
    private static final String CONFIG_ID = "client-test.0";
    private static final long SERVER_TIMEOUT = 5000; //msecs
    private static final double CLIENT_TIMEOUT = 10.0; //secs

    @Test
    public void testPing() {
        try (Tester tester = new Tester()) {
            Request req = new Request("frt.rpc.ping");
            tester.invokeSync(req);
            System.out.println("Got ping response at " + System.currentTimeMillis());
            assertFalse("Invocation failed: " + req.errorCode() + ": " + req.errorMessage(),
                        req.isError());
            assertEquals(0, req.returnValues().size());
        }
    }

    /**
     * Test getConfig with default parameters
     */
    @Test
    public void testGetConfig() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest();
            tester.invokeSync(req.getRequest());
            verifyOkResponse(req);
            verifyConfigChanged(req);
        }
    }

    /**
     * Test getConfig with default parameters
     */
    @Test
    public void testGetConfigNoMd5() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest();
            tester.invokeSync(req.getRequest());
            verifyOkResponse(req);
        }
    }

    /*
     * Test getting the same config twice. The second request that is sent contains the configMd5 from
     * the previously received response. Hence, the server timeout is triggered before the server
     * responds with unchanged config.
     */
    @Test
    public void testGetConfigTwice() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest();
            tester.invokeSync(req.getRequest());
            verifyOkResponse(req);
            verifyConfigChanged(req);

            // Save away the config checksums for use in next request
            PayloadChecksums payloadChecksums = req.getNewChecksums();
            //System.out.println("Returned config md5=" + payloadChecksums);

            // Get again
            JRTClientConfigRequest newReq = createRequest(payloadChecksums, 0);
            tester.invokeSync(newReq.getRequest());
            verifyOkResponse(newReq);
            verifyConfigUnchanged(newReq);
        }
    }

    /**
     * Test reloading config and getting the new config
     */
    @Test
    public void testReloadConfig() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest();
            tester.invokeSync(req.getRequest());
            verifyOkResponse(req);
            verifyConfigChanged(req);
            long generation = req.getRequestGeneration();

            // Save away the config checksums for use in next request
            PayloadChecksums payloadChecksums = req.getNewChecksums();

            // reload and check that we really get a new config
            tester.getConfigServer().deployNewConfig("configs/baz");

            JRTClientConfigRequest newReq = createRequest(payloadChecksums, 0);

            //printRequest(newReq);
            tester.invokeSync(newReq.getRequest());
            verifyOkResponse(newReq);
            verifyConfigChanged(newReq);
            assertTrue(newReq.getNewGeneration() > generation);
        }
    }

    /**
     * Verifies that response has empty payload when server has unchanged config but new application generation.
     */
    @Test
    public void testEmptyPayloadForNewGeneration() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest();

            tester.invokeSync(req.getRequest());
            verifyOkResponse(req);
            verifyConfigChanged(req);

            // Save away the config checksums and generation for use in next request
            PayloadChecksums payloadChecksums = req.getNewChecksums();
            long generation = req.getNewGeneration();

            // reload same config to set new generation
            tester.getConfigServer().deployNewConfig("configs/foo");

            JRTClientConfigRequest newReq = createRequest(payloadChecksums, generation);

            tester.invokeSync(newReq.getRequest());
            assertTrue("Valid return values", newReq.validateResponse());
            assertTrue("More recent generation", newReq.getNewGeneration() > generation);
            assertFalse("Updated flag in response is false", newReq.hasUpdatedConfig());
            PayloadChecksums payloadChecksums2 = newReq.getNewChecksums();
            assertEquals("Equal config md5 as previous response",
                         payloadChecksums2.getForType(MD5),
                         payloadChecksums.getForType(MD5));
            assertEquals("Equal config xxhash64 as previous response",
                         payloadChecksums2.getForType(XXHASH64),
                         payloadChecksums.getForType(XXHASH64));
            verifyConfigUnchanged(newReq);
        }
    }

    /**
     * Test getConfig with invalid config md5sum
     */
    @Test
    public void testInvalidConfigMd5() {
        try (Tester tester = new Tester()) {
            JRTClientConfigRequest req = createRequest(PayloadChecksums.from("asdf", "fdsa"), 0);
            tester.invokeSync(req.getRequest());
            assertEquals(ILLEGAL_CONFIG_MD5, req.errorCode());
        }
    }

    void verifyOkResponse(JRTClientConfigRequest req) {
        //System.out.println("Got config response at " + System.currentTimeMillis());
        assertNull(req.errorMessage(), req.errorMessage());
        assertTrue(req.getRequest().errorMessage(), req.validateResponse());
    }

    void verifyConfigChanged(JRTClientConfigRequest req) {
        assertTrue(req.errorMessage(), (req.errorCode() == 0));
        assertTrue(req.toString(), req.hasUpdatedConfig());
    }

    void verifyConfigUnchanged(JRTClientConfigRequest req) {
        assertTrue(req.errorMessage(), (req.errorCode() == 0));
        assertFalse(req.hasUpdatedConfig());
    }

    @SuppressWarnings({"UnusedDeclaration"})
    String getPayload(JRTClientConfigRequest req) {
        return req.getNewPayload().toString();
    }

    @SuppressWarnings({"UnusedDeclaration"})
    void printRequest(Request req) {
        Values parameters = req.parameters();

        System.out.println("Request:");
        for (int i = 0; i <= 4; i++) {
            System.out.println("param[" + i + "]: " + parameters.get(i).asString());
        }
        System.out.println("param[5]: " + parameters.get(5).asInt64());
        System.out.println("[end]");
    }

    JRTClientConfigRequest createRequest() {
        return createRequest(PayloadChecksums.empty(), 0);
    }

    JRTClientConfigRequest createRequest(PayloadChecksums payloadChecksums, long generation) {
        return JRTClientConfigRequestV3.createWithParams(
                new ConfigKey<>(DEF_NAME, CONFIG_ID, "config"), DefContent.fromList(Collections.emptyList()),
                "localhost", payloadChecksums, generation, SERVER_TIMEOUT,
                Trace.createNew(), CompressionType.UNCOMPRESSED, Optional.empty());
    }

    private static class Tester implements AutoCloseable {

        private final ConfigTester tester;
        private final Supervisor supervisor;
        private final Target target;

        public Tester() {
            tester = new ConfigTester();
            tester.createAndStartConfigServer();
            supervisor = new Supervisor(new Transport());
            target = supervisor.connect(tester.getConfigServerSpec());
        }

        @Override
        public void close() {
            supervisor.transport().shutdown().join();
            if (target != null) target.close();
            tester.close();
        }

        void invokeSync(Request request) {
            target.invokeSync(request, CLIENT_TIMEOUT);
        }

        TestConfigServer getConfigServer() {
            return tester.getConfigServer();
        }
    }
}
