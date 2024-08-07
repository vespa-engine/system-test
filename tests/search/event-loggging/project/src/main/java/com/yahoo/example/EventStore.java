// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example;

import com.yahoo.search.logging.LoggerEntry;

public interface EventStore {

    void add(LoggerEntry event);

    int eventCount();

    String last();

}
