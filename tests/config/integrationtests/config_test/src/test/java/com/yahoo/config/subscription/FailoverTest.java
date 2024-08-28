// Copyright Vespa.ai. All rights reserved.
package com.yahoo.config.subscription;

import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.JRTConfigRequester;
import com.yahoo.config.subscription.impl.JRTConfigSubscription;
import com.yahoo.foo.BarConfig;
import com.yahoo.vespa.config.Connection;
import com.yahoo.vespa.config.ConnectionPool;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Test;

import java.util.logging.Level;
import java.util.logging.Logger;

import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasChanged;
import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasNotChanged;
import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedSuccess;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

public class FailoverTest {
    private final java.util.logging.Logger log = Logger.getLogger(FailoverTest.class.getName());

    private ConfigSubscriber subscriber;

    @After
    public void closeSubscriber() {
        if (subscriber != null) subscriber.close();
    }

    @Test
    /*
     * Basic functionality of the API when we programmatically execute failover of sources inside the subscriptions
     */
    public void testBasicFailoverInduced() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServers(2);
            tester.deploy("configs/foo0");
            ConfigSourceSet sources = tester.configSourceSet();

            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscribeToBar(sources);
            ConfigHandle<FooConfig> fh = subscribeToFoo(sources);

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            Connection currentConnection = connectionPool(fh).getCurrent();
            log.log(Level.INFO, "current source=" + currentConnection.getAddress());
            tester.stopConfigServerMatchingSource(currentConnection);

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            log.info("Reconfiguring to foo1/");
            tester.deploy("configs/foo1");
            boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals("0bar", bh.getConfig().barValue());
            assertEquals("1foo", fh.getConfig().fooValue());

            log.info("Reconfiguring to foo2/");
            tester.deploy("configs/foo2");
            newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertEquals("1bar", bh.getConfig().barValue());
            assertEquals("1foo", fh.getConfig().fooValue());

            log.info("Redeploying foo2/");
            tester.deploy("configs/foo2");
            assertNextConfigHasNotChanged(subscriber, bh, fh);
        }
    }

    @Test
    public void testFailoverInvisibleToSubscriber() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServers(2);
            tester.deploy("configs/foo0");
            ConfigSourceSet sources = tester.configSourceSet();

            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscribeToBar(sources);
            ConfigHandle<FooConfig> fh = subscribeToFoo(sources);

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            ConnectionPool connectionPool = connectionPool(fh);
            Connection current = connectionPool.getCurrent();
            tester.stopConfigServerMatchingSource(current);

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            TestConfigServer inUse = tester.getInUse(connectionPool);
            inUse.stop();
            assertNextConfigHasNotChanged(subscriber, bh, fh);

            assertNextConfigHasNotChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");

            assertNextConfigHasNotChanged(subscriber, bh, fh);
            assertNextConfigHasNotChanged(subscriber, bh, fh);
            assertNextConfigHasNotChanged(subscriber, bh, fh);
            assertNextConfigHasNotChanged(subscriber, bh, fh);
        }
    }

    @Test
    public void testFailoverWithOneServer() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            tester.deploy("configs/foo0");

            ConfigSourceSet sources = tester.sourceSet();
            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscribeToBar(sources);
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertTrue(bh.isChanged());

            tester.getConfigServer().deployNewConfig("configs/foo2");
            assertNextConfigHasChanged(subscriber, bh);
        }
    }

    @Test
    public void testBasicFailover() throws InterruptedException {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServers(2);
            tester.deploy("configs/foo0");
            ConfigSourceSet sources = tester.configSourceSet();
            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscribeToBar(sources);
            ConfigHandle<FooConfig> fh = subscribeToFoo(sources);
            JRTConfigRequester bhRequester = ((JRTConfigSubscription<BarConfig>) bh.subscription()).requester();
            JRTConfigRequester fhRequester = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester();
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertEquals(fhRequester, bhRequester);
            // Kill current source, wait for failover
            ConnectionPool connectionPool = bhRequester.getConnectionPool();
            Connection current = connectionPool.getCurrent();
            log.log(Level.INFO, "current=" + current.getAddress());
            tester.stopConfigServerMatchingSource(current);
            Thread.sleep(ConfigTester.timingValues().getSubscribeTimeout() * 3);
            assertNotEquals(current.toString(), connectionPool.getCurrent().toString());
            //assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            // Change config on servers (including whatever one we stopped earlier, not in use anyway), verify subscriber is working
            log.info("Reconfiguring to foo1/, current generation " + subscriber.getGeneration());
            tester.deploy("configs/foo1");

            // Want to see a reconfig here, sooner or later
            for (int i = 0; i < 10; i++) {
                if (subscriber.nextConfig(waitWhenExpectedSuccess, false)) {
                    assertFalse(bh.isChanged());
                    assertTrue(fh.isChanged());
                    assertEquals(bh.getConfig().barValue(), "0bar");
                    assertEquals(fh.getConfig().fooValue(), "1foo");
                    break;
                }
                log.info("i=" + i + ", generation=" + subscriber.getGeneration());
                if (i == 9) fail("No reconfig");
            }
        }
    }

    private ConfigHandle<BarConfig> subscribeToBar(ConfigSourceSet sources) {
        return subscriber.subscribe(BarConfig.class, "b", sources, ConfigTester.timingValues());
    }

    private ConfigHandle<FooConfig> subscribeToFoo(ConfigSourceSet sources) {
        return subscriber.subscribe(FooConfig.class, "f", sources, ConfigTester.timingValues());
    }

    private ConnectionPool connectionPool(ConfigHandle<?> configHandle) {
        return ((JRTConfigSubscription<?>) configHandle.subscription()).requester().getConnectionPool();
    }

}
