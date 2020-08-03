// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.supermodelclient;

import java.util.Map;
import java.util.List;

import com.yahoo.config.subscription.ConfigSubscriber;
import com.yahoo.config.subscription.ConfigHandle;
import com.yahoo.cloud.config.LbServicesConfig;

public class SuperModelClient {
    private final ConfigSubscriber subscriber = new ConfigSubscriber();
    private ConfigHandle<LbServicesConfig> lbHandle;
    private long lastGen = -1;

    public SuperModelClient(String configId) {
        lbHandle = subscriber.subscribe(LbServicesConfig.class, configId);
    }

    void loopPrintNewConfig() {
        while (true) {
            if (subscriber.nextConfig()) {
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
                for (Map.Entry<String, LbServicesConfig.Tenants.Applications.Hosts> teah : tea.getValue().hosts().entrySet()) {
                    for (Map.Entry<String, LbServicesConfig.Tenants.Applications.Hosts.Services> teahs : teah.getValue().services().entrySet()) {
                        System.out.println(te.getKey() + "," + tea.getKey() + "," + teahs.getKey()); // tenant,app,servicename
                    }
                }
            }
        }
    }

    public static void main(String[] args) {
        SuperModelClient app = new SuperModelClient("*");
        app.loopPrintNewConfig();
    }
}
