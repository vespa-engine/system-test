// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.GenericConfigHandle;
import com.yahoo.config.subscription.impl.GenericConfigSubscriber;
import com.yahoo.config.subscription.impl.JRTConfigRequester;
import com.yahoo.config.subscription.impl.JRTConfigSubscription;
import com.yahoo.log.LogLevel;
import com.yahoo.vespa.config.ConfigKey;
import com.yahoo.vespa.config.ConfigTest;
import com.yahoo.vespa.config.Connection;
import com.yahoo.vespa.config.ConnectionPool;
import com.yahoo.vespa.config.JRTConnectionPool;
import com.yahoo.vespa.config.RawConfig;
import com.yahoo.vespa.config.TimingValues;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Test;

import com.yahoo.foo.BarConfig;

import static org.junit.Assert.*;

public class FailoverTest extends ConfigTest {
    private java.util.logging.Logger log = java.util.logging.Logger.getLogger(BasicSubscriptionTest.class.getName());

    private ConfigSubscriber subscriber;
    private GenericConfigSubscriber genSubscriber;

    @After
    public void closeSubscriber() {
        if (subscriber != null) subscriber.close();
        if (genSubscriber != null) genSubscriber.close();
    }

    @Test
    /*
     * Basic functionality of the API when we programmatically execute failover of sources inside the subscriptions
     */
    public void testBasicFailoverInduced() {
        ConfigSourceSet sources = setUp3ConfigServers("configs/foo0");

        subscriber = new ConfigSubscriber(sources);
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, getTestTimingValues());

        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");
        ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
        Connection currentConnection = connectionPool.getCurrent();
        log.log(LogLevel.INFO, "current source=" + currentConnection.getAddress());
        stopConfigServerMatchingSource(currentConnection);

        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());

        log.info("Reconfiguring to foo1/");
        deployOn3ConfigServers("configs/foo1");
        // Find next that is not current
        Connection newConnection;
        do {
            newConnection = connectionPool.setNewCurrentConnection();
        } while (currentConnection.getAddress().equals(newConnection.getAddress()));
        log.log(LogLevel.INFO, "newConnection=" + newConnection.getAddress());
        stopConfigServerMatchingSource(newConnection);
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals("0bar", bh.getConfig().barValue());
        assertEquals("1foo", fh.getConfig().fooValue());

        log.info("Reconfiguring to foo2/");
        deployOn3ConfigServers("configs/foo2");
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertFalse(fh.isChanged());
        assertEquals("1bar", bh.getConfig().barValue());
        assertEquals("1foo", fh.getConfig().fooValue());

        log.info("Redeploying foo2/");
        deployOn3ConfigServers("configs/foo2");
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
    }

    private void stopConfigServerMatchingSource(Connection connection) {
        TestConfigServer configServer = getConfigServerMatchingSource(connection)
                .orElseThrow(() -> new RuntimeException("Could not get config server matching source for " + connection));
        stop(configServer);
    }

    private TestConfigServer getInUse(ConfigSubscriber s, ConfigSourceSet sources) {
        if (s.requesters.size() > 1) fail("Not one requester");
        Connection connection = s.requesters().get(sources).getConnectionPool().getCurrent();
        Optional<TestConfigServer> configServer = getConfigServerMatchingSource(connection);
        return configServer.orElseThrow(RuntimeException::new);
    }

    private Optional<TestConfigServer> getConfigServerMatchingSource(Connection connection) {
        Optional<TestConfigServer> configServer = Optional.empty();
        int port = Integer.parseInt(connection.getAddress().split("/")[1]);
        for (TestConfigServer cs : configServerCluster.keySet()) {
            if (cs.getSpec().port() == port) configServer = Optional.of(cs);
        }
        return configServer;
    }

    @Test
    public void testFailoverInvisibleToSubscriber() {
        ConfigSourceSet sources = setUp3ConfigServers("configs/foo0");

        subscriber = new ConfigSubscriber(sources);
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, getTestTimingValues());

        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
        Connection current = connectionPool.getCurrent();
        stopConfigServerMatchingSource(current);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");

        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());

        TestConfigServer inUse = getInUse(subscriber, sources);
        inUse.stop();
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");

        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
    }
    
    /**
     * Failover during nextGeneration() loop, like proxy
     */
    @Test
    public void testFailoverGenericSubscriberNextGenerationLoop() {
        ConfigSourceSet sources = setUp3ConfigServers("configs/foo0");
        Map<ConfigSourceSet, JRTConfigRequester> requesterMap = new HashMap<>();
        requesterMap.put(sources, new JRTConfigRequester(new JRTConnectionPool(sources), new TimingValues()));
        genSubscriber = new GenericConfigSubscriber(requesterMap);
        GenericConfigHandle bh = genSubscriber.subscribe(new ConfigKey<>(BarConfig.getDefName(), "b", BarConfig.getDefNamespace()),
                                                         Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), sources, getTestTimingValues());
        GenericConfigHandle fh = genSubscriber.subscribe(new ConfigKey<>(FooConfig.getDefName(), "f", FooConfig.getDefNamespace()),
                                                         Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA), sources, getTestTimingValues());
        assertTrue(genSubscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertPayloadMatches(bh, ".*barValue.*0bar.*");
        assertPayloadMatches(fh, ".*fooValue.*0foo.*");
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        stop(getInUse(genSubscriber, sources));
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        assertPayloadMatches(bh, ".*barValue.*0bar.*");
        assertPayloadMatches(fh, ".*fooValue.*0foo.*");
        
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());

        // A redeploy some time after a failover
        deployOn3ConfigServers("configs/foo1");
        assertTrue(genSubscriber.nextConfig(waitWhenExpectedSuccess));
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertPayloadMatches(bh, ".*barValue.*0bar.*");
        assertPayloadMatches(fh, ".*fooValue.*1foo.*");
    }
    
    private void assertPayloadMatches(GenericConfigHandle bh, String regex) {
        RawConfig rc = bh.getRawConfig();
        String payloadS = rc.getPayload().toString();
        int pFlags = Pattern.MULTILINE+Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(payloadS).matches());
    }

    @Test
    public void testFailoverOneSpec() {
        ConfigSourceSet set = getTestSourceSet();
        getConfigServer().deployNewConfig("configs/foo0");

        subscriber = new ConfigSubscriber(set);
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", set, getTestTimingValues());

        ConnectionPool connectionPool = ((JRTConfigSubscription<BarConfig>) bh.subscription()).requester().getConnectionPool();
        String s1 = connectionPool.getCurrent().getAddress();
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());

        connectionPool.setNewCurrentConnection();
        String s2 = connectionPool.getCurrent().getAddress();
        connectionPool.setNewCurrentConnection();
        String s3 = connectionPool.getCurrent().getAddress();
        connectionPool.setNewCurrentConnection();
        String s4 = connectionPool.getCurrent().getAddress();
        
        assertEquals(s1, s2);
        assertEquals(s2, s3);        
        assertEquals(s3, s4);  
        
        getConfigServer().deployNewConfig("configs/foo2");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
    }
    
    @Test
    public void testBasicFailover() throws InterruptedException {
        ConfigSourceSet sources = setUp3ConfigServers("configs/foo0");
        subscriber = new ConfigSubscriber(sources);
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, getTestTimingValues());
        ConnectionPool connectionPool = ((JRTConfigSubscription<BarConfig>) bh.subscription()).requester().getConnectionPool();
        Connection current = connectionPool.getCurrent();
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertEquals(subscriber.requesters().size(), 1);
        // Kill current source, wait for failover
        log.log(LogLevel.INFO, "current=" + current.getAddress());
        stopConfigServerMatchingSource(current);
        Thread.sleep(getTestTimingValues().getSubscribeTimeout()*2);
        assertNotEquals(current.toString(), connectionPool.getCurrent().toString());
        //assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        // Change config on servers (including whatever one we stopped earlier, not in use anyway), verify subscriber is working
        log.info("Reconfiguring to foo1/, current generation " + subscriber.getGeneration());
        deployOn3ConfigServers("configs/foo1");

        // Want to see a reconfig here, sooner or later
        for (int i = 0 ; i<10 ; i++) {
            if (subscriber.nextConfig(waitWhenExpectedSuccess)) {
                assertFalse(bh.isChanged());
                assertTrue(fh.isChanged());
                assertEquals(bh.getConfig().barValue(), "0bar");
                assertEquals(fh.getConfig().fooValue(), "1foo");
                break;
            }
            log.info("i=" + i + ", generation=" + subscriber.getGeneration());
            if (i==9) fail("No reconfig");
        }
    }

}
