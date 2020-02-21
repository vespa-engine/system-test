// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.JRTConfigSubscription;
import com.yahoo.foo.BarConfig;
import com.yahoo.log.LogLevel;
import com.yahoo.vespa.config.ConfigTester;
import com.yahoo.vespa.config.Connection;
import com.yahoo.vespa.config.ConnectionPool;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Test;

import static com.yahoo.vespa.config.ConfigTester.waitWhenExpectedFailure;
import static com.yahoo.vespa.config.ConfigTester.waitWhenExpectedSuccess;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

public class FailoverTest {
    private java.util.logging.Logger log = java.util.logging.Logger.getLogger(BasicSubscriptionTest.class.getName());

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

            boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
            Connection currentConnection = connectionPool.getCurrent();
            log.log(LogLevel.INFO, "current source=" + currentConnection.getAddress());
            tester.stopConfigServerMatchingSource(currentConnection);

            newConf = subscriber.nextConfig(waitWhenExpectedFailure);
            assertFalse(newConf);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            log.info("Reconfiguring to foo1/");
            tester.deployOn3ConfigServers("configs/foo1");
            // Find next that is not current
            Connection newConnection;
            do {
                newConnection = connectionPool.setNewCurrentConnection();
            } while (currentConnection.getAddress().equals(newConnection.getAddress()));
            log.log(LogLevel.INFO, "newConnection=" + newConnection.getAddress());
            tester.stopConfigServerMatchingSource(newConnection);
            newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
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
            newConf = subscriber.nextConfig(waitWhenExpectedFailure);
            assertFalse(newConf);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());
        }
    }

    @Test
    public void testFailoverInvisibleToSubscriber() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSourceSet sources = tester.setUp3ConfigServers("configs/foo0");

            subscriber = new ConfigSubscriber(sources);
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b", sources, ConfigTester.getTestTimingValues());
            ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f", sources, ConfigTester.getTestTimingValues());

            boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
            ConnectionPool connectionPool = ((JRTConfigSubscription<FooConfig>) fh.subscription()).requester().getConnectionPool();
            Connection current = connectionPool.getCurrent();
            tester.stopConfigServerMatchingSource(current);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");

            newConf = subscriber.nextConfig(waitWhenExpectedFailure);
            assertFalse(newConf);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            TestConfigServer inUse = tester.getInUse(subscriber, sources);
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

            tester.getConfigServer().deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
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
            Thread.sleep(ConfigTester.getTestTimingValues().getSubscribeTimeout() * 2);
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
