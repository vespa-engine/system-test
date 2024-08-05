// Copyright Vespa.ai. All rights reserved.
package com.yahoo.config.subscription;

import com.yahoo.config.AppConfig;
import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.GenericConfigHandle;
import com.yahoo.config.subscription.impl.GenericConfigSubscriber;
import com.yahoo.config.subscription.impl.JRTConfigRequester;
import com.yahoo.foo.BarConfig;
import com.yahoo.log.LogSetup;
import com.yahoo.vespa.config.ConfigKey;
import com.yahoo.vespa.config.JRTConnectionPool;
import com.yahoo.vespa.config.RawConfig;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Test;

import java.util.List;
import java.util.regex.Pattern;

import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasChanged;
import static com.yahoo.config.subscription.ConfigTester.assertNextConfigHasNotChanged;
import static com.yahoo.config.subscription.ConfigTester.timingValues;
import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedSuccess;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class GenericSubscriptionTest {

    private GenericConfigSubscriber subscriber;

    @After
    public void closeSubscriber() {
        if (subscriber != null) subscriber.close();
    }

    @Test
    public void testGenericJRTSubscription() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              List.of(AppConfig.CONFIG_DEF_SCHEMA),
                                                              timingValues());
            assertNextConfigHasChanged(subscriber, handle);
            RawConfig config = handle.getRawConfig();
            assertConfigMatches(config.getPayload().toString(), ".*message.*msg1.*");
            assertNextConfigHasNotChanged(subscriber, handle);
            assertNextConfigHasNotChanged(subscriber, handle);
            assertEquals(subscriber.getGeneration(), tester.getConfigServer().getApplicationGeneration());
            assertEquals(subscriber.getGeneration(), config.getGeneration());

            // Reconfiguring to bar/
            tester.getConfigServer().deployNewConfig("configs/bar");
            assertNextConfigHasChanged(subscriber, handle);
            config = handle.getRawConfig();
            assertConfigMatches(config.getPayload().toString(), ".*message.*msg2.*");
            assertNextConfigHasNotChanged(subscriber, handle);
        }
    }

    @Test
    public void testNextGeneration() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              List.of(AppConfig.CONFIG_DEF_SCHEMA),
                                                              timingValues());
            assertNextConfigHasChanged(subscriber, handle);
            RawConfig config = handle.getRawConfig();
            assertConfigMatches(config.getPayload().toString(), ".*message.*msg1.*");

            assertNextConfigHasNotChanged(subscriber, handle);
            assertNextConfigHasNotChanged(subscriber, handle);

            // Reconfiguring to bar/
            tester.getConfigServer().deployNewConfig("configs/bar");
            assertNextConfigHasChanged(subscriber, handle);
            config = handle.getRawConfig();
            assertConfigMatches(config.getPayload().toString(), ".*message.*msg2.*");
            assertEquals(subscriber.getGeneration(), tester.getConfigServer().getApplicationGeneration());
            assertEquals(subscriber.getGeneration(), config.getGeneration());
        }
    }

    @Test
    public void testServerFailingNextConfigFalse() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              List.of(AppConfig.CONFIG_DEF_SCHEMA),
                                                              timingValues());
            assertNextConfigHasChanged(subscriber, handle);
            String payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg1.*");
            tester.getConfigServer().stop();

            assertNextConfigHasNotChanged(subscriber, handle);
        }
    }

    @Test
    public void testMultipleSubsSameThing() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            tester.getConfigServer().deployNewConfig("configs/foo0");
            GenericConfigHandle bh1 = subscriber.subscribe(new ConfigKey<>("bar", "b1", "foo"),
                                                           List.of(BarConfig.CONFIG_DEF_SCHEMA),
                                                           timingValues());
            GenericConfigHandle bh2 = subscriber.subscribe(new ConfigKey<>("bar", "b2", "foo"),
                                                           List.of(BarConfig.CONFIG_DEF_SCHEMA),
                                                           timingValues());
            GenericConfigHandle fh1 = subscriber.subscribe(new ConfigKey<>("foo", "f1", "config"),
                                                           List.of(FooConfig.CONFIG_DEF_SCHEMA),
                                                           timingValues());
            GenericConfigHandle fh2 = subscriber.subscribe(new ConfigKey<>("foo", "f2", "config"),
                                                           List.of(FooConfig.CONFIG_DEF_SCHEMA),
                                                           timingValues());
            GenericConfigHandle fh3 = subscriber.subscribe(new ConfigKey<>("foo", "f3", "config"),
                                                           List.of(FooConfig.CONFIG_DEF_SCHEMA),
                                                           timingValues());
            assertNextConfigHasChanged(subscriber, bh1, bh2, fh1, fh2, fh3);
            assertConfigMatches(bh1.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(bh2.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh1.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertConfigMatches(fh2.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertConfigMatches(fh3.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");

            assertNextConfigHasNotChanged(subscriber, bh1, bh2, fh1, fh2, fh3);

            // Reconfiguring to foo1/
            tester.getConfigServer().deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertFalse(bh1.isChanged());
            assertFalse(bh2.isChanged());
            assertTrue(fh1.isChanged());
            assertTrue(fh2.isChanged());
            assertTrue(fh3.isChanged());
            assertConfigMatches(bh1.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(bh2.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh1.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            assertConfigMatches(fh2.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            assertConfigMatches(fh3.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
        }
    }

    @Test
    public void testBasicReconfig() {
        try (ConfigTester tester = new ConfigTester()) {
            TestConfigServer configServer = tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            configServer.deployNewConfig("configs/foo0");
            GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"),
                                                          List.of(BarConfig.CONFIG_DEF_SCHEMA),
                                                          timingValues());
            GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"),
                                                          List.of(FooConfig.CONFIG_DEF_SCHEMA),
                                                          timingValues());

            assertNextConfigHasChanged(subscriber, bh, fh);
            RawConfig bConfig = bh.getRawConfig();
            RawConfig fConfig = fh.getRawConfig();
            assertConfigMatches(bConfig.getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fConfig.getPayload().toString(), ".*fooValue.*0foo.*");
            assertEquals(subscriber.getGeneration(), tester.getConfigServer().getApplicationGeneration());
            assertEquals(subscriber.getGeneration(), bConfig.getGeneration());
            assertEquals(subscriber.getGeneration(), fConfig.getGeneration());

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            configServer.deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");

            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            bConfig = bh.getRawConfig();
            fConfig = fh.getRawConfig();
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            assertEquals(subscriber.getGeneration(), tester.getConfigServer().getApplicationGeneration());
            assertEquals(subscriber.getGeneration(), bConfig.getGeneration());
            assertEquals(subscriber.getGeneration(), fConfig.getGeneration());

            configServer.deployNewConfig("configs/foo2");
            assertNextConfigHasNotChanged(subscriber, bh, fh);
        }
    }

    private void assertConfigMatches(String cfg, String regex) {
        int pFlags = Pattern.MULTILINE + Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(cfg).matches());
    }

    @Test
    public void testBasicGenerationChange() {
        try (ConfigTester tester = new ConfigTester()) {
            TestConfigServer configServer = tester.createAndStartConfigServer();
            JRTConfigRequester requester = JRTConfigRequester.create(tester.sourceSet(), timingValues());
            subscriber = new GenericConfigSubscriber(requester);
            configServer.deployNewConfig("configs/foo0");
            GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"),
                                                          List.of(BarConfig.CONFIG_DEF_SCHEMA),
                                                          timingValues());
            GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"),
                                                          List.of(FooConfig.CONFIG_DEF_SCHEMA),
                                                          timingValues());
            assertNextConfigHasChanged(subscriber, bh, fh);
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");

            assertNextConfigHasNotChanged(subscriber, bh, fh);

            configServer.deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess, false));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");

            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess, false));
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess, false));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());
        }
    }

    /**
     * Failover during nextGeneration() loop, like proxy
     */
    @Test
    public void testFailoverGenericSubscriberNextGenerationLoop() {
        LogSetup.initVespaLogging("test");
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServers(2);
            tester.deploy("configs/foo0");
            ConfigSourceSet sources = tester.configSourceSet();

            JRTConfigRequester requester = new JRTConfigRequester(new JRTConnectionPool(sources), timingValues());
            GenericConfigSubscriber genSubscriber = new GenericConfigSubscriber(requester);
            GenericConfigHandle bh = genSubscriber
                    .subscribe(new ConfigKey<>(BarConfig.getDefName(), "b", BarConfig.getDefNamespace()),
                               List.of(BarConfig.CONFIG_DEF_SCHEMA),
                               timingValues());
            GenericConfigHandle fh = genSubscriber
                    .subscribe(new ConfigKey<>(FooConfig.getDefName(), "f", FooConfig.getDefNamespace()),
                               List.of(FooConfig.CONFIG_DEF_SCHEMA), timingValues());
            assertNextConfigHasChanged(genSubscriber, bh, fh);
            assertPayloadMatches(bh, ".*barValue.*0bar.*");
            assertPayloadMatches(fh, ".*fooValue.*0foo.*");

            assertNextConfigHasNotChanged(genSubscriber, bh, fh);

            tester.stopConfigServer(tester.getInUse(requester.getConnectionPool()));
            assertNextConfigHasNotChanged(genSubscriber, bh, fh);
            assertPayloadMatches(bh, ".*barValue.*0bar.*");
            assertPayloadMatches(fh, ".*fooValue.*0foo.*");

            // Redeploy some time after a failover
            tester.deploy("configs/foo1");
            assertTrue(genSubscriber.nextConfig(waitWhenExpectedSuccess, false));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertPayloadMatches(bh, ".*barValue.*0bar.*");
            assertPayloadMatches(fh, ".*fooValue.*1foo.*");

            genSubscriber.close();
        }
    }

    private void assertPayloadMatches(GenericConfigHandle bh, String regex) {
        RawConfig rc = bh.getRawConfig();
        String payloadS = rc.getPayload().toString();
        int pFlags = Pattern.MULTILINE + Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(payloadS).matches());
    }

}
