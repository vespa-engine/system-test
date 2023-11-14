// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.testvespa;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.Exceptions;
import com.yahoo.vespatest.Greeting;


/**
 * A searcher adding a new hit with a message from a class
 * (which happens to be in a bundle).
 */
public class SimpleSearcher extends Searcher {

    private final String message;

    public SimpleSearcher() {
        message = Greeting.greeting();
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("Running simpleSearcher", true, 3);
        Result result = execution.search(query); // Pass on to the next searcher to get results
        Hit hit = new Hit("test");
        hit.setField("message", message);
        result.hits().add(hit);
        query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
        return result;
    }

}

