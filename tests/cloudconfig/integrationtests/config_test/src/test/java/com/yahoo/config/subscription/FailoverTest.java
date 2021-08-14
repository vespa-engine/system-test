// Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.JRTConfigSubscription;
import com.yahoo.foo.BarConfig;
import com.yahoo.log.LogLevel;
import com.yahoo.vespa.config.Connection;
import com.yahoo.vespa.config.ConnectionPool;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Test;

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
            ConfigSourceSet sources = tester.setUp3ConfigServers("configs/foo0");

            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, ConfigTester.getTestTimingValues());
            ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, ConfigTester.getTestTimingValues());

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
            Connection currentConnection = connectionPool.getCurrent();
            log.log(LogLevel.INFO, "current source=" + currentConnection.getAddress());
            tester.stopConfigServerMatchingSource(currentConnection);

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            log.info("Reconfiguring to foo1/");
            tester.deployOn3ConfigServers("configs/foo1");
            // Find next that is not current
            Connection newConnection;
            do {
                newConnection = connectionPool.switchConnection(currentConnection);
            } while (currentConnection.getAddress().equals(newConnection.getAddress()));
            log.log(LogLevel.INFO, "newConnection=" + newConnection.getAddress());
            tester.stopConfigServerMatchingSource(newConnection);
            boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
            assertTrue(newConf);
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals("0bar", bh.getConfig().barValue());
            assertEquals("1foo", fh.getConfig().fooValue());

            log.info("Reconfiguring to foo2/");
            tester.deployOn3ConfigServers("configs/foo2");
            newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertEquals("1bar", bh.getConfig().barValue());
            assertEquals("1foo", fh.getConfig().fooValue());

            log.info("Redeploying foo2/");
            tester.deployOn3ConfigServers("configs/foo2");
            assertNextConfigHasNotChanged(subscriber, bh, fh);
        }
    }

    @Test
    public void testFailoverInvisibleToSubscriber() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSourceSet sources = tester.setUp3ConfigServers("configs/foo0");

            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, ConfigTester.getTestTimingValues());
            ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, ConfigTester.getTestTimingValues());

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
            Connection current = connectionPool.getCurrent();
            tester.stopConfigServerMatchingSource(current);

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            TestConfigServer inUse = tester.getInUse(subscriber, sources);
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
    public void testFailoverOneSpec() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.startOneConfigServer();
            ConfigSourceSet set = tester.getTestSourceSet();
            tester.getConfigServer().deployNewConfig("configs/foo0");

            subscriber = new ConfigSubscriber(set);
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", set, ConfigTester.getTestTimingValues());

            ConnectionPool connectionPool = ((JRTConfigSubscription<BarConfig>) bh.subscription()).requester().getConnectionPool();
            Connection c1 = connectionPool.getCurrent();
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());

            connectionPool.switchConnection(c1);
            Connection c2 = connectionPool.getCurrent();
            connectionPool.switchConnection(c2);
            Connection c3 = connectionPool.getCurrent();
            connectionPool.switchConnection(c3);
            Connection c4 = connectionPool.getCurrent();

            assertEquals(c1, c2);
            assertEquals(c2, c3);
            assertEquals(c3, c4);

            tester.getConfigServer().deployNewConfig("configs/foo2");
            assertNextConfigHasChanged(subscriber, bh);
        }
    }
    
    @Test
    public void testBasicFailover() throws InterruptedException {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSourceSet sources = tester.setUp3ConfigServers("configs/foo0");
            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, ConfigTester.getTestTimingValues());
            ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, ConfigTester.getTestTimingValues());
            ConnectionPool connectionPool = ((JRTConfigSubscription<BarConfig>) bh.subscription()).requester().getConnectionPool();
            Connection current = connectionPool.getCurrent();
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertEquals(subscriber.requesters().size(), 1);
            // Kill current source, wait for failover
            log.log(LogLevel.INFO, "current=" + current.getAddress());
            tester.stopConfigServerMatchingSource(current);
            Thread.sleep(ConfigTester.getTestTimingValues().getSubscribeTimeout() * 3);
            assertNotEquals(current.toString(), connectionPool.getCurrent().toString());
            //assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            // Change config on servers (including whatever one we stopped earlier, not in use anyway), verify subscriber is working
            log.info("Reconfiguring to foo1/, current generation " + subscriber.getGeneration());
            tester.deployOn3ConfigServers("configs/foo1");

            // Want to see a reconfig here, sooner or later
            for (int i = 0; i < 10; i++) {
                if (subscriber.nextConfig(waitWhenExpectedSuccess)) {
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

}
