// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.AbstractComponent;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * @author musum
 */
public class EventStoreImpl extends AbstractComponent implements EventStore {

    private final AtomicInteger events = new AtomicInteger(0);

    public void add(String event) {
        System.out.println("Adding event");
        events.incrementAndGet();
    }

    public int getEventCount() {
        return events.get();
    }

}
