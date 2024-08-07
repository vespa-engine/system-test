// Copyright Vespa.ai. All rights reserved.
package com.yahoo.config.subscription;

import com.yahoo.config.AppConfig;
import com.yahoo.config.FooConfig;
import com.yahoo.foo.BarConfig;
import com.yahoo.jrt.Request;
import com.yahoo.jrt.Spec;
import com.yahoo.jrt.Supervisor;
import com.yahoo.jrt.Target;
import com.yahoo.jrt.Transport;
import com.yahoo.vespa.config.Connection;
import com.yahoo.vespa.config.ConnectionPool;
import com.yahoo.vespa.config.TimingValues;
import com.yahoo.vespa.config.testutil.TestConfigServer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

/**
 * Helper class for unit tests to make it easier to start and stop config server(s)
 * and make sure the config server always uses a free, available port.
 *
 * @author Harald Musum
 */
public class ConfigTester implements AutoCloseable {

    private static final java.util.logging.Logger log = Logger.getLogger(ConfigTester.class.getName());

    private static final PortRange portRange = new PortRange();
    private final List<TestConfigServer> cluster = new ArrayList<>();
    private final HashMap<TestConfigServer, Thread> threads = new LinkedHashMap<>();

    // How long to wait for config in nextConfig() method, when expecting result to be success (new config available)
    // or failure (no new config)
    public static final long waitWhenExpectedSuccess = 20000L;
    public static final long waitWhenExpectedFailure = 2000L;


    private final ConfigSubscriber subscriber;

    public ConfigTester() {
        this.subscriber = new ConfigSubscriber();
    }

    public TestConfigServer createAndStartConfigServer() {
        TestConfigServer server = createConfigServer();
        cluster.add(server);
        log.log(Level.FINE, "starting configserver on port: " + server.getSpec().port());
        startConfigServer(server);
        return server;
    }

    public void createAndStartConfigServers(int count) {
        IntStream.range(0, count).forEach(i -> createAndStartConfigServer());
    }

    public ConfigSourceSet configSourceSet() {
        return new ConfigSourceSet(cluster.stream()
                                          .map(configServer -> configServer.getSpec().toString())
                                          .collect(Collectors.toList()));
    }

    public void stopConfigServer(TestConfigServer cs) {
        Objects.requireNonNull(cs, "stop() cannot be called with null value");
        Thread t = threads.get(cs);
        log.log(Level.INFO, "Stopping configserver running on port " + cs.getSpec().port() + "...");
        cs.stop();
        try {
            t.join();
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        log.log(Level.INFO, "Config server running on port " + cs.getSpec().port() + " stopped");
    }

    /**
     * Returns RPC connect spec for a config server (an arbitrary server if there are more than one).
     *
     * @return a Spec for the running ConfigServer
     */
    public Spec getConfigServerSpec() { return getConfigServer().getSpec(); }

    public static TimingValues timingValues() {
        return new TimingValues(
                2000,  // successTimeout
                500,   // errorTimeout
                500,   // initialTimeout
                6000,  // subscribeTimeout
                0);   // fixedDelay
    }

    public TestConfigServer getConfigServer() { return cluster.get(0); }

    public ConfigSubscriber getSubscriber() { return subscriber; }

    public void ensureServerRunning(TestConfigServer server) {
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
        return !req.isError();
    }

    @Override
    public void close() {
        subscriber.close();
        threads.keySet().forEach(configServer -> {
            System.out.println("DEBUG:" + configServer);
            stopConfigServer(configServer);
        });
    }

    private static class PortRange {
        private static final int first = 18250;
        private static final int last = 18420;
        private int value = first;

        synchronized int next() {
            if (value > last) {
                throw new RuntimeException("no ports available in range (" + first + " - " + last + ")");
            }
            return value++;
        }
    }

    // Get the next port from a pre-allocated range
    public static int findAvailablePort() {
        return portRange.next();
    }

    public ConfigSourceSet sourceSet() {
        return new ConfigSourceSet(getConfigServerSpec().toString());
    }

    private TestConfigServer createConfigServer() {
        return new TestConfigServer(findAvailablePort(), "configs/def-files", "configs/foo");
    }

    private void startConfigServer(TestConfigServer configServer) {
        Thread t = new Thread(configServer);
        t.start();
        ensureServerRunning(configServer);
        threads.put(configServer, t);
    }

    public void deploy(String configDir) {
        for (TestConfigServer cfgServer : cluster) {
            cfgServer.deployNewConfig(configDir);
        }
    }

    public Optional<TestConfigServer> getConfigServerMatchingSource(Connection connection) {
        Optional<TestConfigServer> configServer = Optional.empty();
        int port = Integer.parseInt(connection.getAddress().split("/")[1]);
        for (TestConfigServer cs : cluster) {
            if (cs.getSpec().port() == port) configServer = Optional.of(cs);
        }
        return configServer;
    }

    public TestConfigServer getInUse(ConnectionPool connectionPool) {
        Optional<TestConfigServer> configServer = getConfigServerMatchingSource(connectionPool.getCurrent());
        return configServer.orElseThrow(RuntimeException::new);
    }

    public void stopConfigServerMatchingSource(Connection connection) {
        TestConfigServer configServer = getConfigServerMatchingSource(connection)
                .orElseThrow(() -> new RuntimeException("Could not get config server matching source for " + connection));
        stopConfigServer(configServer);
    }

    public ConfigHandle<AppConfig> subscribeToAppConfig(ConfigSubscriber subscriber, String configId) {
        return subscriber.subscribe(AppConfig.class, configId, sourceSet(), timingValues());
    }

    public ConfigHandle<FooConfig> subscribeToFooConfig(ConfigSubscriber subscriber, String configId) {
        return subscriber.subscribe(FooConfig.class, configId, sourceSet(), timingValues());
    }

    public ConfigHandle<BarConfig> subscribeToBarConfig(ConfigSubscriber subscriber, String configId) {
        return subscribeToBarConfig(subscriber, configId, timingValues());
    }

    public ConfigHandle<BarConfig> subscribeToBarConfig(ConfigSubscriber subscriber, String configId, TimingValues timingValues) {
        return subscriber.subscribe(BarConfig.class, configId, sourceSet(), timingValues);
    }

    static void assertNextConfigHasChanged(ConfigSubscriber subscriber, ConfigHandle<?>... configHandles) {
        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
        assertTrue(newConf);
        Arrays.stream(configHandles).forEach(ch -> {
            assertTrue(ch.isChanged());
            assertNotNull(ch.getConfig());
        });
    }

    static void assertNextConfigHasNotChanged(ConfigSubscriber subscriber, ConfigHandle<?>... configHandles) {
        boolean newConf = subscriber.nextConfig(waitWhenExpectedFailure, false);
        assertFalse(newConf);
        Arrays.stream(configHandles).forEach(ch -> assertFalse(ch.isChanged()));
    }

}
