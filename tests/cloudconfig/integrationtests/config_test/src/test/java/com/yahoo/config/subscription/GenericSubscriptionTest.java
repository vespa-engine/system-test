// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.config.subscription;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.*;

import com.yahoo.config.AppConfig;
import com.yahoo.config.FooConfig;
import com.yahoo.foo.BarConfig;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import com.yahoo.config.subscription.impl.GenericConfigHandle;
import com.yahoo.config.subscription.impl.GenericConfigSubscriber;
import com.yahoo.vespa.config.ConfigKey;
import com.yahoo.vespa.config.ConfigTest;

import java.util.Arrays;
import java.util.regex.Pattern;

public class GenericSubscriptionTest extends ConfigTest {

    private GenericConfigSubscriber subscriber;
    
    @Before
    public void createSubscriber() {
        subscriber = new GenericConfigSubscriber();
    }
    
    @After
    public void closeSubscriber() {
        if (subscriber!=null) subscriber.close();
    }
    
    @Test
    public void testGenericJRTSubscription() {
        GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"), Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(handle.isChanged());
        String payloadS = handle.getRawConfig().getPayload().toString();
        assertConfigMatches(payloadS, ".*message.*msg1.*");
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());
        assertThat(subscriber.getGeneration(), is(getConfigServer().getApplicationGeneration()));
        assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
        assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

        // Reconfiguring to bar/
        getConfigServer().deployNewConfig("configs/bar");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(handle.isChanged());
        payloadS = handle.getRawConfig().getPayload().toString();
        assertConfigMatches(payloadS, ".*message.*msg2.*");
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());
    }
    
    @Test
    public void testNextGeneration() {
        GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"), Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertTrue(handle.isChanged());
        String payloadS = handle.getRawConfig().getPayload().toString();
        assertConfigMatches(payloadS, ".*message.*msg1.*");
        assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());
        assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());

        // Reconfiguring to bar/
        getConfigServer().deployNewConfig("configs/bar");
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertTrue(handle.isChanged());
        payloadS = handle.getRawConfig().getPayload().toString();
        assertConfigMatches(payloadS, ".*message.*msg2.*");
        assertThat(subscriber.getGeneration(), is(getConfigServer().getApplicationGeneration()));
        assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
        assertThat(handle.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
    }
    
    @Test
    public void testServerFailingNextConfigFalse() {
        GenericConfigHandle handle = subscriber.subscribe(new ConfigKey<>("app", "app.0", "config"), Arrays.asList(AppConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertTrue(handle.isChanged());
        String payloadS = handle.getRawConfig().getPayload().toString();
        assertConfigMatches(payloadS, ".*message.*msg1.*");
        cServer1.stop();
        assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(handle.isChanged());
    }

    @Test
    public void testMultipleSubsSameThing() {
        getConfigServer().deployNewConfig("configs/foo0");
        GenericConfigHandle bh1 = subscriber.subscribe(new ConfigKey<>("bar", "b1", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle bh2 = subscriber.subscribe(new ConfigKey<>("bar", "b2", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA),getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle fh1 = subscriber.subscribe(new ConfigKey<>("foo", "f1", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle fh2 = subscriber.subscribe(new ConfigKey<>("foo", "f2", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle fh3 = subscriber.subscribe(new ConfigKey<>("foo", "f3", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA),getTestSourceSet(), getTestTimingValues());
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
        getConfigServer().deployNewConfig("configs/foo1");
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

    @Test
    public void testBasicReconfig() throws InterruptedException {
        getConfigServer().deployNewConfig("configs/foo0");
        GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
        assertThat(subscriber.getGeneration(), is(getConfigServer().getApplicationGeneration()));
        assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
        assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        
        getConfigServer().deployNewConfig("configs/foo1");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
        
        getConfigServer().deployNewConfig("configs/foo2");
        assertTrue(subscriber.nextConfig(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertFalse(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
        assertThat(subscriber.getGeneration(), is(getConfigServer().getApplicationGeneration()));
        assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));
        assertThat(bh.getRawConfig().getGeneration(), is(subscriber.getGeneration()));

        getConfigServer().deployNewConfig("configs/foo2");
        assertFalse(subscriber.nextConfig(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
    }
    
    private void assertConfigMatches(String cfg, String regex) {
        int pFlags = Pattern.MULTILINE+Pattern.DOTALL;
        Pattern pattern = Pattern.compile(regex, pFlags);
        assertTrue(pattern.matcher(cfg).matches());
    }
    
    @Test
    public void testBasicGenerationChange() throws InterruptedException {
        getConfigServer().deployNewConfig("configs/foo0");
        GenericConfigHandle bh = subscriber.subscribe(new ConfigKey<>("bar", "b4", "foo"), Arrays.asList(BarConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        GenericConfigHandle fh = subscriber.subscribe(new ConfigKey<>("foo", "f4", "config"), Arrays.asList(FooConfig.CONFIG_DEF_SCHEMA), getTestSourceSet(), getTestTimingValues());
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertTrue(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*0foo.*");
        assertFalse(subscriber.nextGeneration(waitWhenExpectedFailure));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());
        
        getConfigServer().deployNewConfig("configs/foo1");
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertFalse(bh.isChanged());
        assertTrue(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*0bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
        
        getConfigServer().deployNewConfig("configs/foo2");
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertTrue(bh.isChanged());
        assertFalse(fh.isChanged());
        assertConfigMatches(bh.getRawConfig().getPayload().toString(), ".*barValue.*1bar.*");
        assertConfigMatches(fh.getRawConfig().getPayload().toString(), ".*fooValue.*1foo.*");
        getConfigServer().deployNewConfig("configs/foo2");
        assertTrue(subscriber.nextGeneration(waitWhenExpectedSuccess));
        assertFalse(bh.isChanged());
        assertFalse(fh.isChanged());        
    }
}
