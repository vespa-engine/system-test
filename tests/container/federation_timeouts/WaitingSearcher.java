// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.searchchain.Execution;

import java.util.logging.Logger;

public class WaitingSearcher extends Searcher {

    private static Logger log = Logger.getLogger(WaitingSearcher.class.getName());

    @Override
    public Result search(Query query, Execution execution) {
        log.info("Query timeout in " + query.properties().get("sourceName") + ": " + query.getTimeout());

        long waitTime = query.properties().getLong("waitTime", 0l);
        try { Thread.sleep(waitTime); } catch (InterruptedException e) { }
        query.trace("Waited " + waitTime + " ms", 1);
        return execution.search(query);
    }

}
