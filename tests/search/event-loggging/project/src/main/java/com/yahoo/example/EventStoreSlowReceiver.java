// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.AbstractComponent;
import com.yahoo.search.logging.LoggerEntry;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * @author musum
 */
public class EventStoreSlowReceiver extends AbstractComponent implements EventStore {

    private final AtomicInteger events = new AtomicInteger(0);

    public void add(LoggerEntry entry) {
        try {
            Thread.sleep((long) (Math.random() * 100));
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
        events.incrementAndGet();
    }

    @Override
    public int eventCount() {
        return events.get();
    }

    @Override
    public String last() {
        return "";
    }

}
