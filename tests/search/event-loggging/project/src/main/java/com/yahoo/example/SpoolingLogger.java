// Copyright Vespa.ai. All rights reserved.
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
        super(new Spooler(Path.of(Defaults.getDefaults().underVespaHome("var/spool/vespa/events")), 3, Clock.systemUTC(), true, 5));
        this.eventStore = eventStore;
        start();
    }

    @Override
    public boolean transport(LoggerEntry entry) {
        eventStore.add(entry);
        return true;
    }

}
