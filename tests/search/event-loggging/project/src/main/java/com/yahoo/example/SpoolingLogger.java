// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.annotation.Inject;
import com.yahoo.search.logging.AbstractSpoolingLogger;
import com.yahoo.search.logging.LoggerEntry;
import com.yahoo.search.logging.Spooler;
import com.yahoo.vespa.defaults.Defaults;
import java.nio.file.Path;
import java.time.Clock;

/**
 * @author musum
 */
public class SpoolingLogger extends AbstractSpoolingLogger {

    private final EventStore eventStore;

    @Inject
    public SpoolingLogger(EventStore eventStore) {
        super(new Spooler(Path.of(Defaults.getDefaults().underVespaHome("var/spool/vespa/events")), 3, Clock.systemUTC(), true));
        this.eventStore = eventStore;
    }

    @Override
    public boolean transport(LoggerEntry entry) {
        eventStore.add(entry);
        return true;
    }

}
