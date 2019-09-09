package com.yahoo.vespa.configtestapp;

import com.yahoo.messagebus.MessagebusConfig;
import com.yahoo.config.subscription.ConfigSubscriber;
import com.yahoo.config.subscription.ConfigHandle;
import com.yahoo.log.*;

import java.util.Date;
import java.util.logging.Logger;
import java.io.FileWriter;
import java.io.IOException;

/**
 * Application that subscribes to config defined in messagebus.1.def and
 * generated code in MessagebusConfig.java.
 *
 * @author Harald Musum
 */
public class AppService {
    private static final Logger log = Logger.getLogger("client");

    private static final String CONFIG_ID = "client";
    private static String outputFile = "routingconfig.out";

    private int timesConfigured = 0;
    private MessagebusConfig config = null;
    private final String configId;

    public AppService() {
        this(CONFIG_ID, "client1");
    }

    public AppService(String configId, String appName) {
	LogSetup.initVespaLogging("test " + appName);
        this.configId = configId;
        ConfigSubscriber subscriber = new ConfigSubscriber();
        ConfigHandle<MessagebusConfig> h = subscriber.subscribe(MessagebusConfig.class, configId);
        while (true) {
	    // Use nextGeneration instead of nextConfig to make it possible to test
	    // new config generations too.
            if (subscriber.nextGeneration()) {
                configure(subscriber.getGeneration(), h.getConfig());
            }
        }
    }

    private void configure(long generation, MessagebusConfig config) {
        log.log(LogLevel.INFO, System.currentTimeMillis() + ": " + configId + " got configure callback");
        this.config = config;
        Integer routeSize = config.routingtable(0).route().size();
        log.log(LogLevel.INFO, "Number of routes for " + outputFile + ":" + routeSize + " (generation " + generation + ")");
        try {
            FileWriter writer = new FileWriter(outputFile);
            writer.write(routeSize.toString());
            writer.write("\n");
            writer.write((new Long(generation)).toString());
            writer.flush();
            writer.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        timesConfigured++;
    }

    public int timesConfigured() {
        return timesConfigured;
    }

    public void setConfigured(boolean configured) {
        if (! configured) {
            timesConfigured = 0;
        } else {
            if (timesConfigured < 1) {
                timesConfigured = 1;
            }
        }
    }

    public MessagebusConfig getConfig() {
        return config;
    }

    private static void usage() {
        System.out.println("Missing option: <output file>");
    }

    public static void main(String args[]) {
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
