// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.AbstractComponent;
import com.yahoo.search.logging.LoggerEntry;
import com.yahoo.text.Utf8;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * @author musum
 */
public class EventStoreImpl extends AbstractComponent implements EventStore {

    private static final Logger log = java.util.logging.Logger.getLogger(EventStoreImpl.class.getName());

    private final AtomicInteger events = new AtomicInteger(0);
    private volatile String last = "";

    public void add(LoggerEntry entry) {
        last = Utf8.toString(Base64.getDecoder().decode(entry.blob().array()));
        log.log(Level.FINE, "Adding event " + entry + ", last blob=" + last);
        events.incrementAndGet();
    }

    @Override
    public int eventCount() { return events.get(); }

    @Override
    public String last() { return last; }

}
