// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.*;

import com.yahoo.config.AppConfig;
import com.yahoo.config.ConfigurationRuntimeException;
import com.yahoo.config.FooConfig;
import com.yahoo.io.IOUtils;
import com.yahoo.log.LogLevel;
import com.yahoo.vespa.config.ConfigTest;
import com.yahoo.vespa.config.util.ConfigUtils;

import org.junit.After;
import org.junit.Before;
import org.junit.Ignore;
import org.junit.Test;
import com.yahoo.foo.BarConfig;
import com.yahoo.myproject.config.NamespaceConfig;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;

public class BasicSubscriptionTest extends ConfigTest {
    private java.util.logging.Logger log = java.util.logging.Logger.getLogger(BasicSubscriptionTest.class.getName());
    private ConfigSubscriber subscriber;
    
    @Before
    public void createSubscriber() {
        subscriber = new ConfigSubscriber();
    }
    
    @After
    public void closeSubscriber() {
        if (subscriber!=null) subscriber.close();
    }
    
    @Test
    public void testSimpleJRTSubscription() {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.0", getTestSourceSet(), getTestTimingValues());
        subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(appCfgHandle.isChanged());
        assertNotNull(appCfgHandle.getConfig());
        AppConfig a = appCfgHandle.getConfig();
        assertEquals(a.message(), "msg1");

        // Test that config md5 is set correctly
        final File file = new File("configs/foo/app.cfg");
        try {
            String md5 = ConfigUtils.getMd5(new CfgConfigPayloadBuilder().deserialize(Arrays.asList(IOUtils.readFile(file).split("\n"))));
            assertThat(a.getConfigMd5(), is(md5));
        } catch (IOException e) {
            fail("Could not read file " + file);
        }
    }

    @Test
    public void testStateConstraints() {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.1", getTestSourceSet(), getTestTimingValues());
        subscriber.nextConfig(50);
        appCfgHandle.getConfig();
        try {
            subscriber.subscribe(NamespaceConfig.class, "foo");
            fail("Could subscribe after frozen");
        } catch (Exception e) {
            assertTrue(e instanceof IllegalStateException);
        }
        subscriber.close();
        assertFalse(subscriber.nextConfig(1));
    }

    @Test
    public void testServerFailingNextConfigFalse() {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.2", getTestSourceSet(), getTestTimingValues());
        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(appCfgHandle.isChanged());
        assertNotNull(appCfgHandle.getConfig());
        AppConfig a = appCfgHandle.getConfig();
        assertEquals(a.message(), "msg1");
        cServer1.stop();
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(appCfgHandle.isChanged());
    }

    @Test
    public void testNextConfigFalseWhenConfigured() {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.3", getTestSourceSet(), getTestTimingValues());
        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(appCfgHandle.isChanged());
        assertNotNull(appCfgHandle.getConfig());
        AppConfig a = appCfgHandle.getConfig();
        assertEquals(a.message(), "msg1");
        newConf = subscriber.nextConfig(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(appCfgHandle.isChanged());
    }

    @Test
    public void testNextGenerationFalseWhenConfigured() {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.4", getTestSourceSet(), getTestTimingValues());
        boolean newConf = subscriber.nextGeneration(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(appCfgHandle.isChanged());
        assertNotNull(appCfgHandle.getConfig());
        AppConfig a = appCfgHandle.getConfig();
        assertEquals(a.message(), "msg1");
        newConf = subscriber.nextGeneration(waitWhenExpectedFailure);
        assertFalse(newConf);
        assertFalse(appCfgHandle.isChanged());
    }

    @Test
    public void testMultipleSubsSameThing() {
        getConfigServer().deployNewConfig("configs/foo0");
        ConfigHandle<BarConfig> bh1 = subscriber.subscribe(BarConfig.class, "b1", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<BarConfig> bh2 = subscriber.subscribe(BarConfig.class, "b2", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh1 = subscriber.subscribe(FooConfig.class, "f1", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh2 = subscriber.subscribe(FooConfig.class, "f2", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh3 = subscriber.subscribe(FooConfig.class, "f3", getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh1.isChanged());
        assertTrue(bh2.isChanged());
        assertTrue(fh1.isChanged());
        assertTrue(fh2.isChanged());
        assertTrue(fh3.isChanged());
        assertEquals(bh1.getConfig().barValue(), "0bar");
        assertEquals(bh2.getConfig().barValue(), "0bar");
        assertEquals(fh1.getConfig().fooValue(), "0foo");
        assertEquals(fh2.getConfig().fooValue(), "0foo");
        assertEquals(fh3.getConfig().fooValue(), "0foo");
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(bh1.isChanged());
        assertFalse(bh2.isChanged());
        assertFalse(fh1.isChanged());
        assertFalse(fh2.isChanged());
        assertFalse(fh3.isChanged());
        log.info("Reconfiguring to foo1/");
        getConfigServer().deployNewConfig("configs/foo1");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
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

    @Test
    public void testBasicReconfig() throws InterruptedException {
        getConfigServer().deployNewConfig("configs/foo0");
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b4", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f4", getTestSourceSet(), getTestTimingValues());

        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");

        newConf = subscriber.nextConfig(2000);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());

        log.info("Reconfiguring to foo1/");
        getConfigServer().deployNewConfig("configs/foo1");
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "1foo");

        log.info("Reconfiguring to foo2/");
        getConfigServer().deployNewConfig("configs/foo2");
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertFalse(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "1bar");
        assertEquals(fh.getConfig().fooValue(), "1foo");

        log.info("Redeploying foo2/");
        getConfigServer().deployNewConfig("configs/foo2");
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
    }

    @Test
    public void testBasicGenerationChange() throws InterruptedException {
        getConfigServer().deployNewConfig("configs/foo0");
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b5", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f5", getTestSourceSet(), getTestTimingValues());

        boolean newConf = subscriber.nextGeneration(waitWhenExpectedSuccess);
        long lastGen = subscriber.getGeneration();
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");

        newConf = subscriber.nextGeneration(2000);
        assertFalse(newConf);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());

        log.info("Reconfiguring to foo1/");
        getConfigServer().deployNewConfig("configs/foo1");
        newConf = subscriber.nextGeneration(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(subscriber.getGeneration() > lastGen);
        lastGen = subscriber.getGeneration();
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "1foo");

        log.info("Reconfiguring to foo2/");
        getConfigServer().deployNewConfig("configs/foo2");
        newConf = subscriber.nextGeneration(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(subscriber.getGeneration() > lastGen);
        lastGen = subscriber.getGeneration();
        assertTrue(bh.isChanged());
        assertFalse(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "1bar");
        assertEquals(fh.getConfig().fooValue(), "1foo");

        log.info("Redeploying foo2/");
        getConfigServer().deployNewConfig("configs/foo2");
        newConf = subscriber.nextGeneration(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(subscriber.getGeneration() > lastGen);
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
    }

    @Test
    //@Ignore
    public void testQuickReconfigs() throws InterruptedException {
        getConfigServer().deployNewConfig("configs/foo0");
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b6", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f6", getTestSourceSet(), getTestTimingValues());

        boolean newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");
        long generation = waitForServerSwitch(0);

        // reconfiguring twice before calling nextConfig again
        getConfigServer().deployNewConfig("configs/foo1");
        generation = waitForServerSwitch(generation);
        getConfigServer().deployNewConfig("configs/foo4");
        waitForServerSwitch(generation);
        newConf = subscriber.nextConfig(waitWhenExpectedSuccess);
        assertTrue(newConf);
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "4bar");
        assertEquals(fh.getConfig().fooValue(), "4foo");
    }

    private long waitForServerSwitch(long currentGeneration) throws InterruptedException {
        long endTime = System.currentTimeMillis() + 60_000;
        while (System.currentTimeMillis() < endTime && getConfigServer().getApplicationGeneration() <= currentGeneration) {
            Thread.sleep(100);
        }
        long nextGeneration = getConfigServer().getApplicationGeneration();
        assertTrue(nextGeneration > currentGeneration);
        return nextGeneration;
    }

    @Test
    public void testExtendSuccessTimeout() throws InterruptedException {
        ConfigHandle<AppConfig> appCfgHandle = subscriber.subscribe(AppConfig.class, "app.5", getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(appCfgHandle.isChanged());
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
    }

    @Test
    /**
     * If a reload comes between subscribe and nextConfig, or multiple reloads between nextConfigs, handle that the payload then is empty, i.e. empty is not propagated to subscriber
     */
    @Ignore
    public void testEmptyPayloadWhenUnHandledReqPreviously() throws InterruptedException {
        log.log(LogLevel.INFO, "Starting testEmptyPayloadWhenUnHandledReqPreviously");
        getConfigServer().deployNewConfig("configs/foo0");
        ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "b7", getTestSourceSet(), getTestTimingValues());
        ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "f7", getTestSourceSet(), getTestTimingValues());
        getConfigServer().deployNewConfig("configs/foo0");
        Thread.sleep(1000);
        log.log(LogLevel.INFO, "Calling nextConfig 1st time");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "0foo");
        getConfigServer().deployNewConfig("configs/foo1");
        Thread.sleep(1000);
        getConfigServer().deployNewConfig("configs/foo1");
        log.log(LogLevel.INFO, "Calling nextConfig 2nd time");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertEquals(bh.getConfig().barValue(), "0bar");
        assertEquals(fh.getConfig().fooValue(), "1foo");
    }

    @Test
    public void testSubscribeTimeout() {
        getConfigServer().setGetConfDelayTimeMillis(1000);
        getConfigServer().deployNewConfig("configs/foo0");
        try {
            subscriber.subscribe(BarConfig.class, "b8", getTestSourceSet(), getTestTimingValues().setSubscribeTimeout(200));
            fail("Subscribe should have timed out and thrown");
        } catch (Exception e) {
            assertTrue(e instanceof ConfigurationRuntimeException);
            assertTrue(e.getMessage().matches(".*timed out.*"));
        }
    }

}
