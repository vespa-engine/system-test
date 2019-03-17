// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.config;

import com.yahoo.config.subscription.ConfigSourceSet;
import com.yahoo.jrt.Request;
import com.yahoo.jrt.Spec;
import com.yahoo.jrt.Supervisor;
import com.yahoo.jrt.Target;
import com.yahoo.jrt.Transport;
import com.yahoo.log.LogLevel;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Before;

import java.util.HashMap;
import java.util.stream.Collectors;

/**
 * Helper class for unit tests to make it easier to start and stop config server(s)
 * and make sure the config server always uses a free, available port.
 *
 * Automatically starts 1 config server and option to start 2 more. All are cleaned up in @After
 *
 * @author Harald Musum<
 */
public class ConfigTest {
    private java.util.logging.Logger log = java.util.logging.Logger.getLogger(ConfigTest.class.getName());

    public static final String DEF_NAME = "app";
    public static final String CONFIG_MD5 = "";

    protected TestConfigServer cServer1;
    protected TestConfigServer cServer2;
    protected TestConfigServer cServer3;
    protected Thread cS1;
    protected Thread cS2;
    protected Thread cS3;

    protected final HashMap<TestConfigServer, Thread> configServerCluster = new HashMap<>();

    // How long to wait for config in nextConfig() method, when expecting result to be success (new config available)
    // or failure (no new config)
    protected static final long waitWhenExpectedSuccess = 60000L;
    protected static final long waitWhenExpectedFailure = 5000L;

    @Before
    public void startConfigServer() {
        cServer1 = createConfigServer();
        log.log(LogLevel.DEBUG, "starting configserver on port: " + cServer1.getSpec().port());
        cS1 = startConfigServer(cServer1);
        ensureServerRunning(cServer1);
        configServerCluster.put(cServer1, cS1);
    }

    @After
    public void stopConfigServers() {
        for (HashMap.Entry<TestConfigServer, Thread> entry : configServerCluster.entrySet()) {
            stop(entry.getKey(), entry.getValue());
        }
    }

    protected void stop(TestConfigServer cs, Thread t) {
        if (cs == null) {
            return;
        }
        log.log(LogLevel.DEBUG, "Stopping configserver ...");
        cs.stop();
        try {
            t.join();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        log.log(LogLevel.DEBUG, "done.");
    }

    /**
     * Returns RPC connect spec for config server.
     *
     * @return a Spec for the running ConfigServer
     */
    public Spec getConfigServerSpec() { return cServer1.getSpec(); }

    public static TimingValues getTestTimingValues() { return new TimingValues(
            2000,  // successTimeout
            500,   // errorTimeout
            500,   // initialTimeout
            6000,  // subscribeTimeout
            250,   // unconfiguredDelay
            500,   // configuredErrorDelay
            250,   // fixedDelay
            5);    // maxDelayMultiplier
    }

    public TestConfigServer getConfigServer() { return cServer1; }

    protected void ensureServerRunning(TestConfigServer server) {
        long start = System.currentTimeMillis();
        boolean stop = false;
        while (!ping(server) && !stop) {
            try {
                Thread.sleep(10);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            if (System.currentTimeMillis() > (start + 30000)) {
                stop = true;
            }
        }
    }

    private boolean ping(TestConfigServer server) {
        Supervisor supervisor = new Supervisor(new Transport());
        Target target = supervisor.connect(server.getSpec());
        Request req = new Request("frt.rpc.ping");
        target.invokeSync(req, 5.0);
        System.out.println("Got ping response at " + System.currentTimeMillis());
        return !req.isError();
    }

    private static class PortRange {
        private int first = 18250;
        private int last  = 18420;
        private int value = first;
        synchronized int next() {
            if (value > last) {
                throw new RuntimeException("no ports available in range (" + first + " - " + last + ")");
            }
            return value++;
        }
    }

    private final static PortRange portRange = new PortRange();

    // Get the next port from a pre-allocated range
    public static int findAvailablePort() {
        return portRange.next();
    }

    protected ConfigSourceSet getTestSourceSet() {
        return new ConfigSourceSet(getConfigServerSpec().toString());
    }

    /**
     * 3 sources with given configs dir
     */
    protected ConfigSourceSet setUp3ConfigServers(String configDir) {
        cServer2 = createConfigServer();
        cS2 = startConfigServer(cServer2);
        cServer3 = createConfigServer();
        cS3 = startConfigServer(cServer3);

        configServerCluster.put(cServer2, cS2);
        configServerCluster.put(cServer3, cS3);

        deployOn3ConfigServers(configDir);
        return new ConfigSourceSet(
                configServerCluster.keySet().stream()
                        .map(configServer -> configServer.getSpec().toString()).collect(Collectors.toList()));
    }

    private TestConfigServer createConfigServer() {
        return new TestConfigServer(findAvailablePort(), "configs/def-files", "configs/foo");
    }

    private Thread startConfigServer(TestConfigServer configServer) {
        Thread t = new Thread(configServer);
        t.start();
        ensureServerRunning(configServer);
        return t;
    }

    protected void deployOn3ConfigServers(String configDir) {
        for (TestConfigServer cfgServer : configServerCluster.keySet()) {
            cfgServer.deployNewConfig(configDir);
        }
    }
}
