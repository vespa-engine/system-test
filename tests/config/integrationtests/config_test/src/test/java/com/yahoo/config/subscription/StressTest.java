// Copyright Vespa.ai. All rights reserved.
package com.yahoo.config.subscription;

import com.yahoo.config.FooConfig;
import com.yahoo.foo.BarConfig;
import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedFailure;
import static com.yahoo.config.subscription.ConfigTester.waitWhenExpectedSuccess;
import static org.junit.Assert.assertTrue;

public class StressTest {

    @Test
    public void testManySubscribers() throws InterruptedException {
        try (ConfigTester tester = new ConfigTester()) {
            tester.createAndStartConfigServers(2);
            tester.deploy("configs/foo0");
            ConfigSourceSet sources = tester.configSourceSet();
            Map<Integer, BarSubscriberThread> barSubscribers = new HashMap<>();
            Map<Integer, FooSubscriberThread> fooSubscribers = new HashMap<>();
            Map<Integer, Thread> barThreads = new HashMap<>();
            Map<Integer, Thread> fooThreads = new HashMap<>();

            int threads = 10;
            for (int i = 0; i < threads; i++) {
                final BarSubscriberThread barSubscriberThread = new BarSubscriberThread(sources);
                barSubscribers.put(i, barSubscriberThread);
                barThreads.put(i, new Thread(barSubscriberThread));
                final FooSubscriberThread fooSubscriberThread = new FooSubscriberThread(sources);
                fooSubscribers.put(i, fooSubscriberThread);
                fooThreads.put(i, new Thread(fooSubscriberThread));
            }
            for (int i = 0; i < threads; i++) {
                barThreads.get(i).start();
                fooThreads.get(i).start();
            }
            for (int i = 0; i < threads; i++) {
                barThreads.get(i).join();
                fooThreads.get(i).join();
            }
            for (int i = 0; i < threads; i++) {
                assertTrue(barSubscribers.get(i).allOK);
                assertTrue(fooSubscribers.get(i).allOK);
            }
        }
    }

    private static class BarSubscriberThread implements Runnable {
        private final ConfigSubscriber subscriber;
        boolean allOK = false;

        public BarSubscriberThread(ConfigSourceSet sources) {
            subscriber = new ConfigSubscriber(sources);
        }

        @Override
        public void run() {
            ConfigHandle<BarConfig> bh = subscriber.subscribe(BarConfig.class, "bar");
            allOK = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            allOK = allOK && bh.isChanged();
            allOK = allOK && (bh.getConfig().barValue().equals("0bar"));
            allOK = allOK && !subscriber.nextConfig(waitWhenExpectedFailure, false);
            allOK = allOK && !bh.isChanged();
            subscriber.close();
        }
    }

    private static class FooSubscriberThread implements Runnable {
        private final ConfigSubscriber subscriber;
        boolean allOK = false;

        public FooSubscriberThread(ConfigSourceSet sources) {
            subscriber = new ConfigSubscriber(sources);
        }

        @Override
        public void run() {
            ConfigHandle<FooConfig> fh = subscriber.subscribe(FooConfig.class, "foo");
            allOK = subscriber.nextConfig(waitWhenExpectedSuccess, false);
            allOK = allOK && fh.isChanged();
            allOK = allOK && (fh.getConfig().fooValue().equals("0foo"));
            allOK = allOK && !subscriber.nextConfig(waitWhenExpectedFailure, false);
            allOK = allOK && !fh.isChanged();
            subscriber.close();
        }
    }
}
