// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.config;

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
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.Collections;
import java.util.Optional;

import static com.yahoo.vespa.config.ErrorCode.*;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;


/**
 * Tests for different client requests  to config server.  A configserver is started
 * before the class is loaded and reads config from files.
 *
 * @author Harald Musum
 */
public class ConfigClientTest {

    public static final String DEF_NAME = "app";
    public static final String CONFIG_MD5 = "";

    // getConfig parameters
    private static final String CONFIG_ID = "client-test.0";
    private static final long SERVER_TIMEOUT = 5000; //msecs
    private static final double CLIENT_TIMEOUT = 10.0; //secs

    ConfigTester tester;
    private Supervisor supervisor;
    private Target target;

    @Before
    public void setUp() {
        tester = new ConfigTester();
        tester.startOneConfigServer();
        supervisor = new Supervisor(new Transport());
        target = supervisor.connect(tester.getConfigServerSpec());
    }

    @After public void tearDown() {
        supervisor.transport().shutdown().join();
        supervisor = null;
        if (target != null) target.close();
        tester.close();
    }

    public ConfigClientTest() {
    }

    @Test
    public void testPing() {
        Request req = new Request("frt.rpc.ping");
        target.invokeSync(req, CLIENT_TIMEOUT);
        //System.out.println("Got ping response at " + System.currentTimeMillis());
        assertFalse("Invocation failed: " + req.errorCode() + ": " +
                req.errorMessage(),
                req.isError());
        assertEquals(0, req.returnValues().size());
    }

    /**
     *  Test getConfig with default parameters
     */
    @Test
    public void testGetConfig() {
        JRTClientConfigRequest req = createRequest();
        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(req);
        verifyConfigChanged(req);
    }

    /**
     *  Test getConfig with default parameters
     */
    @Test
    public void testGetConfigNoMd5() {
        JRTClientConfigRequest req = createRequest(DEF_NAME, "");
        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(req);
    }

    /*
     * Test getting the same config twice. The second request that is sent contains the configMd5 from
     * the previously received response. Hence, the server timeout is triggered before the server
     * responds with unchanged config.
     */
    @Test
    public void testGetConfigTwice() {
        JRTClientConfigRequest req = createRequest();
        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(req);
        verifyConfigChanged(req);

        // Save away the config md5 for use in next request
        String configMd5 = req.getNewConfigMd5();
        //System.out.println("Returned config md5=" + configMd5);

        // Get again
        JRTClientConfigRequest  newReq = createRequest(DEF_NAME, configMd5);
        target.invokeSync(newReq.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(newReq);
        verifyConfigUnchanged(newReq);
    }

    /**
     *  Test reloading config and getting the new config
     */
    @Test
    public void testReloadConfig() {
        JRTClientConfigRequest req = createRequest();
        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(req);
        verifyConfigChanged(req);
        long generation = req.getRequestGeneration();

        // Save away the config md5 for use in next request
        String configMd5 = req.getNewConfigMd5();

        // reload and check that we really get a new config
        tester.getConfigServer().deployNewConfig("configs/baz");

        JRTClientConfigRequest  newReq = createRequest(DEF_NAME, configMd5);

        //printRequest(newReq);
        target.invokeSync(newReq.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(newReq);
        verifyConfigChanged(newReq);
        assertTrue(newReq.getNewGeneration() > generation);
    }

    /**
     *  Verifies that response has empty payload when server has unchanged config but new application generation.
     */
    @Test
    public void testEmptyPayloadForNewGeneration() {
        JRTClientConfigRequest req = createRequest();

        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        verifyOkResponse(req);
        verifyConfigChanged(req);

        // Save away the config md5 and generation for use in next request
        String configMd5 = req.getNewConfigMd5();
        long generation = req.getNewGeneration();

        // reload same config to set new generation
        tester.getConfigServer().deployNewConfig("configs/foo");

        JRTClientConfigRequest newReq = createRequest(DEF_NAME, configMd5, generation);

        target.invokeSync(newReq.getRequest(), CLIENT_TIMEOUT);
        assertTrue("Valid return values", newReq.validateResponse());
        assertTrue("More recent generation", newReq.getNewGeneration() > generation);
        assertFalse("Updated flag in response is false", newReq.hasUpdatedConfig());
        assertEquals("Equal config md5 as previous response", newReq.getNewConfigMd5(), configMd5);
        assertEquals("Empty payload", 0, newReq.getNewPayload().getData().getByteLength());
    }

    /**
     *  Test getConfig with invalid config md5sum
     */
    @Test
    public void testInvalidConfigMd5() {
        JRTClientConfigRequest req = createRequest(DEF_NAME, "asdf");
        target.invokeSync(req.getRequest(), CLIENT_TIMEOUT);
        assertEquals(ILLEGAL_CONFIG_MD5, req.errorCode());
    }

    void verifyOkResponse(JRTClientConfigRequest req) {
        //System.out.println("Got config response at " + System.currentTimeMillis());
        assertNull(req.errorMessage(), req.errorMessage());
        assertTrue(req.getRequest().errorMessage(), req.validateResponse());
    }

    void verifyConfigChanged(JRTClientConfigRequest req) {
        assertTrue(req.errorMessage(), (req.errorCode() == 0) );
        assertTrue(req.hasUpdatedConfig());
    }

    void verifyConfigUnchanged(JRTClientConfigRequest req) {
        assertTrue(req.errorMessage(), (req.errorCode() == 0) );
        assertFalse(req.hasUpdatedConfig());
        assertEquals(0, req.getNewPayload().getData().getByteLength());
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
            System.out.println("param["+i+"]: "+parameters.get(i).asString());
        }
        System.out.println("param[5]: "+parameters.get(5).asInt64());
        System.out.println("[end]");
    }

    JRTClientConfigRequest createRequest() {
        return createRequest(DEF_NAME, CONFIG_MD5);
    }

    JRTClientConfigRequest createRequest(String name, String configMd5) {
        return createRequest(name, configMd5, 0);
    }

    JRTClientConfigRequest createRequest(String name, String configMd5, long generation) {
        return JRTClientConfigRequestV3.createWithParams(
                new ConfigKey<>(name, CONFIG_ID, "config"), DefContent.fromList(Collections.emptyList()),
                "localhost", configMd5, generation, SERVER_TIMEOUT,
                Trace.createNew(), CompressionType.UNCOMPRESSED, Optional.empty());
    }
}
