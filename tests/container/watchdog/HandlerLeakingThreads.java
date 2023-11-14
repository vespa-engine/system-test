// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.time.Instant;
import java.util.Timer;

import com.yahoo.jdisc.Request;
import com.yahoo.jdisc.Response;
import com.yahoo.jdisc.handler.*;

public class HandlerLeakingThreads extends AbstractRequestHandler {

    // Ensure timer and its thread is not stopped and GCed by cleaner
    private static Timer timer = null;

    public HandlerLeakingThreads() {
        Thread t1 = new Thread(() -> {
            while (true) try { Thread.sleep(1000); } catch (InterruptedException e) {}
        }, "leak-using-runnable");
        t1.setDaemon(true);
        t1.start();

        Thread t2 = new Thread("leak-using-subclass") {
            @Override
            public void run() {
                while (true) try { Thread.sleep(1000); } catch (InterruptedException e) {}
            }
        };
        t2.setDaemon(true);
        t2.start();

        var original = Thread.currentThread().getContextClassLoader();
        Thread.currentThread().setContextClassLoader(getClass().getClassLoader());
        try {
            timer = new Timer("leak-using-context-classloader", true);
        } finally {
            Thread.currentThread().setContextClassLoader(original);
        }
    }

    @Override
    public ContentChannel handleRequest(Request request, ResponseHandler handler) {
        FastContentWriter writer = ResponseDispatch.newInstance(Response.Status.OK).connectFastWriter(handler);
        writer.write("I leak!");
        writer.close();
        return null;
    }
}
