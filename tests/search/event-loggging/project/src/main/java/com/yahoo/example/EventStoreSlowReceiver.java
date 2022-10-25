// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.AbstractComponent;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * @author musum
 */
public class EventStoreSlowReceiver extends AbstractComponent implements EventStore {

    private final AtomicInteger events = new AtomicInteger(0);

    public void add(String event) {
        try {
            Thread.sleep((long) (Math.random() * 100));
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        System.out.println("Adding event");
        events.incrementAndGet();
    }

    public int getEventCount() {
        return events.get();
    }

}
