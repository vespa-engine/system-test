package com.yahoo.vespa.configtestapp;

import com.yahoo.log.LogSetup;
import com.yahoo.messagebus.MessagebusConfig;
import com.yahoo.config.subscription.ConfigSubscriber;
import com.yahoo.config.subscription.ConfigHandle;

import java.util.Date;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Application that subscribes to config defined in messagebus.def and
 * generated code in MessagebusConfig.java.
 *
 * @author Harald Musum
 */
public class AppService {
    private static final Logger log = Logger.getLogger("client");

    private static final String CONFIG_ID = "client";
    private static String outputFile = "routingconfig.out";

    private MessagebusConfig config;
    private final String configId;

    private AppService(String configId, String appName) {
	LogSetup.initVespaLogging("test " + appName);
        this.configId = configId;
        ConfigSubscriber subscriber = new ConfigSubscriber();
        ConfigHandle<MessagebusConfig> h = subscriber.subscribe(MessagebusConfig.class, configId);
        while (true) {
	    // Use nextGeneration instead of nextConfig to make it possible to test
	    // new config generations too.
            if (subscriber.nextGeneration(false)) {
                configure(subscriber.getGeneration(), h.getConfig());
            }
        }
    }

    private void configure(long generation, MessagebusConfig config) {
        log.log(Level.INFO, System.currentTimeMillis() + ": " + configId + " got configure callback");
        this.config = config;
        int routeSize = config.routingtable(0).route().size();
        log.log(Level.INFO, "Number of routes for " + outputFile + ":" + routeSize + " (generation " + generation + ")");
        try {
            FileWriter writer = new FileWriter(outputFile);
            writer.write(Integer.toString(routeSize));
            writer.write("\n");
            writer.write("" + generation);
            writer.flush();
            writer.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static void usage() {
        System.out.println("Missing option: <output file>");
    }

    public static void main(String[] args) {
        System.out.println("Starting app at " + new Date());
        if (args.length < 1) {
            usage();
        } else {
            AppService app;
            outputFile = args[0];
            System.out.println("Using output file " + outputFile);
            if (args.length > 1) {
                app = new AppService(CONFIG_ID, args[1]);
            } else {
                app = new AppService(CONFIG_ID, "client1");
            }
            while (true) {
                try {
                    System.out.println(outputFile + ", sleep 1 min, times=" + app.config.routingtable(0).route().size());
                    Thread.sleep(60000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }
    }
}
