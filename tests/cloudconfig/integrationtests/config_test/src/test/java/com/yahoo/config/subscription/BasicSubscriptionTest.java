// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import com.yahoo.config.AppConfig;
import com.yahoo.config.ConfigurationRuntimeException;
import com.yahoo.config.FooConfig;
import com.yahoo.foo.BarConfig;
import com.yahoo.myproject.config.NamespaceConfig;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.Ignore;
import org.junit.Test;

import java.util.logging.Logger;

import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasChanged;
import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasNotChanged;
import static com.yahoo.config.subscription.ConfigTester.timingValues;
import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedFailure;
import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedSuccess;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

public class BasicSubscriptionTest {

    private final java.util.logging.Logger log = Logger.getLogger(BasicSubscriptionTest.class.getName());

    @Test
    public void testSimpleJRTSubscription() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            ConfigSubscriber subscriber = tester.getSubscriber();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.0");
            assertNextConfigHasChanged(subscriber, appCfgHandle);
            AppConfig a = appCfgHandle.getConfig();
            assertEquals(a.message(), "msg1");
        }
    }

    @Test
    public void testStateConstraints() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            tester.createAndStartConfigServer();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.1");
            subscriber.nextConfig(50, false);
            appCfgHandle.getConfig();
            try {
                subscriber.subscribe(NamespaceConfig.class, "foo");
                fail("Could subscribe after frozen");
            } catch (Exception e) {
                assertTrue(e instanceof IllegalStateException);
            }
            subscriber.close();
            try {
                subscriber.nextConfig(1, false);
                fail("Could call nextConfig() after subscriber was closed");
            } catch (Exception e) {
                // Ignore, SubscriberClosedException is deprecated, so just check that we get an exception
            }
        }
    }

    @Test
    public void testServerFailingNextConfigFalse() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.2");
            assertNextConfigHasChanged(subscriber, appCfgHandle);
            AppConfig a = appCfgHandle.getConfig();
            assertEquals(a.message(), "msg1");
            configServer.stop();
            assertNextConfigHasNotChanged(subscriber, appCfgHandle);
        }
    }

    @Test
    public void testNextConfigFalseWhenConfigured() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            tester.createAndStartConfigServer();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.3");
            assertNextConfigHasChanged(subscriber, appCfgHandle);
            AppConfig a = appCfgHandle.getConfig();
            assertEquals(a.message(), "msg1");
            assertNextConfigHasNotChanged(subscriber, appCfgHandle);
        }
    }

    @Test
    public void testNextGenerationFalseWhenConfigured() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            tester.createAndStartConfigServer();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.4");
            assertNextConfigHasChanged(subscriber, appCfgHandle);
            AppConfig a = appCfgHandle.getConfig();
            assertEquals(a.message(), "msg1");
            assertNextConfigHasNotChanged(subscriber, appCfgHandle);
        }
    }

    @Test
    public void testMultipleSubsSameThing() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.deployNewConfig("configs/foo0");
            ConfigHandle<BarConfig> bh1 = tester.subscribeToBarConfig(subscriber, "b1");
            ConfigHandle<BarConfig> bh2 = tester.subscribeToBarConfig(subscriber, "b2");
            ConfigHandle<FooConfig> fh1 = tester.subscribeToFooConfig(subscriber, "f1");
            ConfigHandle<FooConfig> fh2 = tester.subscribeToFooConfig(subscriber, "f2");
            ConfigHandle<FooConfig> fh3 = tester.subscribeToFooConfig(subscriber, "f3");
            assertNextConfigHasChanged(subscriber, bh1, bh2, fh1, fh2, fh3);
            assertEquals(bh1.getConfig().barValue(), "0bar");
            assertEquals(bh2.getConfig().barValue(), "0bar");
            assertEquals(fh1.getConfig().fooValue(), "0foo");
            assertEquals(fh2.getConfig().fooValue(), "0foo");
            assertEquals(fh3.getConfig().fooValue(), "0foo");

            assertNextConfigHasNotChanged(subscriber, bh1, bh2, fh1, fh2, fh3);

            log.info("Reconfiguring to foo1/");
            configServer.deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertFalse(bh1.isChanged());
            assertFalse(bh2.isChanged());
            assertTrue(fh1.isChanged());
            assertTrue(fh2.isChanged());
            assertTrue(fh3.isChanged());
            assertEquals(bh1.getConfig().barValue(), "0bar");
            assertEquals(bh2.getConfig().barValue(), "0bar");
            assertEquals(fh1.getConfig().fooValue(), "1foo");
            assertEquals(fh2.getConfig().fooValue(), "1foo");
            assertEquals(fh3.getConfig().fooValue(), "1foo");
        }
    }

    @Test
    public void testBasicReconfig() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.deployNewConfig("configs/foo0");
            ConfigHandle<BarConfig> bh = tester.subscribeToBarConfig(subscriber, "b4");
            ConfigHandle<FooConfig> fh = tester.subscribeToFooConfig(subscriber, "f4");

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");

            boolean newConf = subscriber.nextConfig(2000, false);
            assertFalse(newConf);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            log.info("Reconfiguring to foo1/");
            configServer.deployNewConfig("configs/foo1");
            newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "1foo");

            log.info("Reconfiguring to foo2/");
            configServer.deployNewConfig("configs/foo2");
            newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "1bar");
            assertEquals(fh.getConfig().fooValue(), "1foo");

            log.info("Redeploying foo2/");
            configServer.deployNewConfig("configs/foo2");
            assertNextConfigHasNotChanged(subscriber, bh, fh);
        }
    }

    @Test
    public void testBasicGenerationChange() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.deployNewConfig("configs/foo0");
            ConfigHandle<BarConfig> bh = tester.subscribeToBarConfig(subscriber, "b5");
            ConfigHandle<FooConfig> fh = tester.subscribeToFooConfig(subscriber, "f5");

            assertNextConfigHasChanged(subscriber, bh, fh);
            long lastGen = subscriber.getGeneration();

            boolean newConf = subscriber.nextGeneration(2000, false);
            assertFalse(newConf);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            log.info("Reconfiguring to foo1/");
            configServer.deployNewConfig("configs/foo1");
            newConf = subscriber.nextGeneration(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(subscriber.getGeneration() > lastGen);
            lastGen = subscriber.getGeneration();
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "1foo");

            log.info("Reconfiguring to foo2/");
            configServer.deployNewConfig("configs/foo2");
            newConf = subscriber.nextGeneration(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(subscriber.getGeneration() > lastGen);
            lastGen = subscriber.getGeneration();
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "1bar");
            assertEquals(fh.getConfig().fooValue(), "1foo");

            log.info("Redeploying foo2/");
            configServer.deployNewConfig("configs/foo2");
            newConf = subscriber.nextGeneration(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(subscriber.getGeneration() > lastGen);
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());
        }
    }

    @Test
    public void testQuickReconfigs() throws InterruptedException {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.deployNewConfig("configs/foo0");
            ConfigHandle<BarConfig> bh = tester.subscribeToBarConfig(subscriber, "b6");
            ConfigHandle<FooConfig> fh = tester.subscribeToFooConfig(subscriber, "f6");

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");
            long generation = waitForServerSwitch(configServer, 0);

            // reconfiguring twice before calling nextConfig again
            configServer.deployNewConfig("configs/foo1");
            generation = waitForServerSwitch(configServer, generation);
            configServer.deployNewConfig("configs/foo4");
            waitForServerSwitch(configServer, generation);
            boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            assertTrue(newConf);
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "4bar");
            assertEquals(fh.getConfig().fooValue(), "4foo");
        }
    }

    private long waitForServerSwitch(TestConfigServer configServer, long currentGeneration) throws InterruptedException {
        long endTime = System.currentTimeMillis() + 60_000;
        while (System.currentTimeMillis() < endTime && configServer.getApplicationGeneration() <= currentGeneration) {
            Thread.sleep(100);
        }
        long nextGeneration = configServer.getApplicationGeneration();
        assertTrue(nextGeneration > currentGeneration);
        return nextGeneration;
    }

    @Test
    public void testExtendSuccessTimeout() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            tester.createAndStartConfigServer();
            ConfigHandle<AppConfig> appCfgHandle = tester.subscribeToAppConfig(subscriber, "app.5");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, true));
            assertTrue(appCfgHandle.isChanged());
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure, false));
        }
    }

    /*
      If a reload comes between subscribe and nextConfig, or multiple reloads between nextConfigs,
      handle that the payload then is empty, i.e. empty is not propagated to subscriber
     */
    @Test
    @Ignore
    public void testEmptyPayloadWhenUnHandledReqPreviously() throws InterruptedException {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.deployNewConfig("configs/foo0");
            ConfigHandle<BarConfig> bh = tester.subscribeToBarConfig(subscriber, "b7");
            ConfigHandle<FooConfig> fh = tester.subscribeToFooConfig(subscriber, "f7");
            configServer.deployNewConfig("configs/foo0");
            Thread.sleep(1000);

            assertNextConfigHasChanged(subscriber, bh, fh);
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "0foo");

            configServer.deployNewConfig("configs/foo1");
            Thread.sleep(1000);
            configServer.deployNewConfig("configs/foo1");

            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertEquals(bh.getConfig().barValue(), "0bar");
            assertEquals(fh.getConfig().fooValue(), "1foo");
        }
    }

    @Test
    public void testSubscribeTimeout() {
        try (ConfigTester tester = new ConfigTester()) {
            ConfigSubscriber subscriber = tester.getSubscriber();
            TestConfigServer configServer = tester.createAndStartConfigServer();
            configServer.setGetConfDelayTimeMillis(1000);
            configServer.deployNewConfig("configs/foo0");
            try {
                tester.subscribeToBarConfig(subscriber, "b8", timingValues().setSubscribeTimeout(200));
                fail("Subscribe should have timed out and thrown");
            } catch (Exception e) {
                assertTrue(e instanceof ConfigurationRuntimeException);
                assertTrue(e.getMessage().matches(".*timed out.*"));
            }
        }
    }

}
