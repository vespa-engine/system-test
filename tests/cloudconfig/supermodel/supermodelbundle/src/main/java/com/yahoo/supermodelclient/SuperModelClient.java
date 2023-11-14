// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.supermodelclient;

import com.yahoo.cloud.config.LbServicesConfig;
import com.yahoo.config.subscription.ConfigHandle;
import com.yahoo.config.subscription.ConfigSubscriber;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;

public class SuperModelClient {
    private final ConfigSubscriber subscriber = new ConfigSubscriber();
    private ConfigHandle<LbServicesConfig> lbHandle;
    private long lastGen = -1;

    public SuperModelClient(String configId) {
        lbHandle = subscriber.subscribe(LbServicesConfig.class, configId);
    }

    void loopPrintNewConfig() {
        Instant end = Instant.now().plus(Duration.ofSeconds(10));
        while (Instant.now().isBefore(end)) {
            if (subscriber.nextConfig(false)) {
                System.out.println("nextConfig() was true, gen="+subscriber.getGeneration()+", num tenants: "+lbHandle.getConfig().tenants().size());
                if (lbHandle.isChanged()) {
                    printServices();
                }
            }
        }
    }

    private void printServices() {
        // Check generation has increased by one
        long currentGen = subscriber.getGeneration();
        if (lastGen == -1) {
            lastGen = currentGen;  // first one seen
        } else {
            if (currentGen > lastGen) {
                lastGen = currentGen;
            } else {
                System.out.println("Skipped generation change: (from " + lastGen + " to " + currentGen + ")");
            }
        }
        System.out.println("LB services, generation " + currentGen + " :");
        LbServicesConfig lb = lbHandle.getConfig();
        for (Map.Entry<String, LbServicesConfig.Tenants> te : lb.tenants().entrySet()) {
            for (Map.Entry<String, LbServicesConfig.Tenants.Applications> tea : te.getValue().applications().entrySet()) {
                // No endpoints because this is run in a non-hosted setup where endpoints are not added to config
                System.out.printf("%s,%s,%s,%d\n",
                                  te.getKey(),  // tenant
                                  tea.getKey(), // application
                                  tea.getValue().activeRotation(),
                                  tea.getValue().endpoints().size());
            }
        }
    }

    public static void main(String[] args) {
        SuperModelClient app = new SuperModelClient("*");
        app.loopPrintNewConfig();
    }

}
