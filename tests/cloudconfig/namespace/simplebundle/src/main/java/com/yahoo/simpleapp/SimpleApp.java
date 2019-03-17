// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.simpleapp;

import com.yahoo.config.subscription.ConfigSubscriber;
import com.yahoo.config.subscription.ConfigHandle;

import com.yahoo.bar.SimpleConfig;

public class SimpleApp {
    private final ConfigSubscriber subscriber = new ConfigSubscriber();
    private ConfigHandle<SimpleConfig> handle;

    public SimpleApp(String configId) {
        try {
            handle = subscriber.subscribe(SimpleConfig.class, configId);
            subscriber.nextConfig();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void printConfig() {
        try {
            SimpleConfig config = handle.getConfig();
            System.out.println("foo: " + config.foo());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public static void main(String [] args) {
        String configId = System.getenv("VESPA_CONFIG_ID");
        if (configId == null || configId.length() == 0) {
            System.out.println("VESPA_CONFIG_ID environment variable not set");
            System.exit(1);
        }
        SimpleApp app = new SimpleApp(configId);
        app.printConfig();
    }
}
