// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.search.logging.LoggerEntry;

public interface EventStore {

    void add(LoggerEntry event);

    int eventCount();

    String last();

}
