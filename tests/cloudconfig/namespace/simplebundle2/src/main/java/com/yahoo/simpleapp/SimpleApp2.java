// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.simpleapp;

import com.yahoo.config.subscription.ConfigSubscriber;
import com.yahoo.config.subscription.ConfigHandle;

import com.yahoo.bar2.baz_foo.SimpleConfig;
import com.yahoo.bar.baz.ExtraConfig;

public class SimpleApp2 {
    private final ConfigSubscriber subscriber = new ConfigSubscriber();
    private ConfigHandle<SimpleConfig> handleSimple;
    private ConfigHandle<ExtraConfig> handleExtra;

    public SimpleApp2(String configId) {
        try {
            handleSimple = subscriber.subscribe(SimpleConfig.class, configId);
            handleExtra = subscriber.subscribe(ExtraConfig.class, configId);
            subscriber.nextConfig();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void printConfig() {
        try {
            SimpleConfig simpleConfig = handleSimple.getConfig();
            ExtraConfig extraConfig = handleExtra.getConfig();
            System.out.println("foo: " + simpleConfig.foo());
            System.out.println("quux: " + extraConfig.quux());
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
        SimpleApp2 app = new SimpleApp2(configId);
        app.printConfig();
    }
}
