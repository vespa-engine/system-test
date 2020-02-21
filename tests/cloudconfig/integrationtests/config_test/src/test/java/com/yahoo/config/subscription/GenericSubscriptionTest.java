// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import com.yahoo.config.AppConfig;
import com.yahoo.config.FooConfig;
import com.yahoo.config.subscription.impl.GenericConfigHandle;
import com.yahoo.config.subscription.impl.GenericConfigSubscriber;
import com.yahoo.config.subscription.impl.JRTConfigRequester;
import com.yahoo.foo.BarConfig;
import com.yahoo.log.LogSetup;
import com.yahoo.vespa.config.ConfigKey;
import com.yahoo.vespa.config.ConfigTester;
import com.yahoo.vespa.config.JRTConnectionPool;
import com.yahoo.vespa.config.RawConfig;
import com.yahoo.vespa.config.testutil.TestConfigServer;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

import static com.yahoo.vespa.config.ConfigTester.waitWhenExpectedFailure;
import static com.yahoo.vespa.config.ConfigTester.waitWhenExpectedSuccess;
import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertThat;
import static org.junit.Assert.assertTrue;

public class GenericSubscriptionTest {

    private GenericConfigSubscriber subscriber;
    
    @Before
    public void createSubscriber() {
        ConfigSourceSet sourceSet = JRTConfigRequester.defaultSourceSet;
        Map<ConfigSourceSet, JRTConfigRequester> requesterMap = new HashMap<>();
        requesterMap.put(sourceSet, new JRTConfigRequester(new JRTConnectionPool(sourceSet), ConfigTester.getTestTimingValues()));
        subscriber = new GenericConfigSubscriber(requesterMap);
    }
    
    @After
    public void closeSubscriber() {
        if (subscriber!=null) subscriber.close();
    }
    
    @Test
    public void testGenericJRTSubscription() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.startOneConfigServer();
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA),
                                                              tester.getTestSourceSet(),
                                                              ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(handle.isChanged());
            String payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg1.*");
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());
            assertThat(subscriber.getGeneration(), is(tester.getConfigServer().getApplicationGeneration()));
            assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
            assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

            // Reconfiguring to bar/
            tester.getConfigServer().deployNewConfig("configs/bar");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(handle.isChanged());
            payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg2.*");
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());
        }
    }
    
    @Test
    public void testNextGeneration() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.startOneConfigServer();
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA),
                                                              tester.getTestSourceSet(),
                                                              ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertTrue(handle.isChanged());
            String payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg1.*");
            assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());
            assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());

            // Reconfiguring to bar/
            tester.getConfigServer().deployNewConfig("configs/bar");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertTrue(handle.isChanged());
            payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg2.*");
            assertThat(subscriber.getGeneration(), is(tester.getConfigServer().getApplicationGeneration()));
            assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
            assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
        }
    }
    
    @Test
    public void testServerFailingNextConfigFalse() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.startOneConfigServer();
            GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"),
                                                              Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA),
                                                              tester.getTestSourceSet(),
                                                              ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertTrue(handle.isChanged());
            String payloadS = handle.getRawConfig().getPayload().toString();
            assertConfigMatches(payloadS, ".*message.*msg1.*");
            tester.getConfigServer().stop();
            assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(handle.isChanged());
        }
    }

    @Test
    public void testMultipleSubsSameThing() {
        try (ConfigTester tester = new ConfigTester()) {
            tester.startOneConfigServer();
            tester.getConfigServer().deployNewConfig("configs/foo0");
            GenericConfigHandle bh1 = subscriber.subscribe(new ConfigKey<>("bar", "b1", "foo"),
                                                           Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), tester.getTestSourceSet(),
                                                           ConfigTester.getTestTimingValues());
            GenericConfigHandle bh2 = subscriber.subscribe(new ConfigKey<>("bar", "b2", "foo"),
                                                           Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA),
                                                           tester.getTestSourceSet(),
                                                           ConfigTester.getTestTimingValues());
            GenericConfigHandle fh1 = subscriber.subscribe(new ConfigKey<>("foo", "f1", "config"),
                                                           Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),
                                                           tester.getTestSourceSet(),
                                                           ConfigTester.getTestTimingValues());
            GenericConfigHandle fh2 = subscriber.subscribe(new ConfigKey<>("foo", "f2", "config"),
                                                           Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),
                                                           tester.getTestSourceSet(),
                                                           ConfigTester.getTestTimingValues());
            GenericConfigHandle fh3 = subscriber.subscribe(new ConfigKey<>("foo", "f3", "config"),
                                                           Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),
                                                           tester.getTestSourceSet(),
                                                           ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh1.isChanged());
            assertTrue(bh2.isChanged());
            assertTrue(fh1.isChanged());
            assertTrue(fh2.isChanged());
            assertTrue(fh3.isChanged());
            assertConfigMatches(bh1.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(bh2.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh1.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertConfigMatches(fh2.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertConfigMatches(fh3.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(bh1.isChanged());
            assertFalse(bh2.isChanged());
            assertFalse(fh1.isChanged());
            assertFalse(fh2.isChanged());
            assertFalse(fh3.isChanged());

            // Reconfiguring to foo1/
            tester.getConfigServer().deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
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

            // TODO fix
            //assertFalse(fh1.getRawConfig().getPayload().toString().matches(".*fooValue.*foo.*"));
            //assertFalse(fh2.getRawConfig().getPayload().toString().matches(".*fooValue.*foo.*"));
            //assertFalse(fh3.getRawConfig().getPayload().toString().matches(".*fooValue.*foo.*"));
        }
    }

    @Test
    public void testBasicReconfig() {
        try (ConfigTester tester = new ConfigTester()) {
            TestConfigServer configServer = tester.startOneConfigServer();
            configServer.deployNewConfig("configs/foo0");
            GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA),
                                                          tester.getTestSourceSet(), ConfigTester.getTestTimingValues());
            GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),
                                                          tester.getTestSourceSet(), ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertThat(subscriber.getGeneration(), is(configServer.getApplicationGeneration()));
            assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
            assertThat(fh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            configServer.deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");

            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            assertThat(subscriber.getGeneration(), is(configServer.getApplicationGeneration()));
            assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
            assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

            configServer.deployNewConfig("configs/foo2");
            assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());
        }
    }

    private void assertConfigMatches(String cfg, String regex) {
        int pFlags = Pattern.MULTILINE+Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(cfg).matches());
    }
    
    @Test
    public void testBasicGenerationChange() {
        try (ConfigTester tester = new ConfigTester()) {
            TestConfigServer configServer = tester.startOneConfigServer();
            configServer.deployNewConfig("configs/foo0");
            GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA),
                                                          tester.getTestSourceSet(), ConfigTester.getTestTimingValues());
            GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),
                                                          tester.getTestSourceSet(), ConfigTester.getTestTimingValues());
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
            assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            configServer.deployNewConfig("configs/foo1");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertFalse(bh.isChanged());
            assertTrue(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");

            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
            assertFalse(fh.isChanged());
            assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
            assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
            configServer.deployNewConfig("configs/foo2");
            assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
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
            ConfigSourceSet sources = tester.setUp3ConfigServers("configs/foo0");

            Map<ConfigSourceSet, JRTConfigRequester> requesterMap = new HashMap<>();
            requesterMap.put(sources, new JRTConfigRequester(new JRTConnectionPool(sources), ConfigTester.getTestTimingValues()));
            GenericConfigSubscriber genSubscriber = new GenericConfigSubscriber(requesterMap);
            GenericConfigHandle bh = genSubscriber.subscribe(new ConfigKey<>(BarConfig.getDefName(), "b", BarConfig.getDefNamespace()),
                                                             Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), sources, ConfigTester.getTestTimingValues());
            GenericConfigHandle fh = genSubscriber.subscribe(new ConfigKey<>(FooConfig.getDefName(), "f", FooConfig.getDefNamespace()),
                                                             Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA), sources, ConfigTester.getTestTimingValues());
            assertTrue(genSubscriber.nextConfig(waitWhenExpectedSuccess));
            assertTrue(bh.isChanged());
            assertTrue(fh.isChanged());
            assertPayloadMatches(bh, ".*barValue.*0bar.*");
            assertPayloadMatches(fh, ".*fooValue.*0foo.*");
            assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());

            System.out.println("\nDEBUG DEBUG DEBUG right before stopping config server\n");
            tester.stopConfigServer(tester.getInUse(genSubscriber, sources));
            assertFalse(genSubscriber.nextGeneration(waitWhenExpectedFailure));
            assertFalse(bh.isChanged());
            assertFalse(fh.isChanged());
            assertPayloadMatches(bh, ".*barValue.*0bar.*");
            assertPayloadMatches(fh, ".*fooValue.*0foo.*");

            // Redeploy some time after a failover
            tester.deployOn3ConfigServers("configs/foo1");
            System.out.println("\nDEBUG DEBUG DEBUG calling nextConfig()\n");
            assertTrue(genSubscriber.nextConfig(waitWhenExpectedSuccess));
            System.out.println("\nDEBUG DEBUG DEBUG after calling nextConfig()\n");
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
        int pFlags = Pattern.MULTILINE+Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(payloadS).matches());
    }

}
