// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.component.ComponentId;

public class AddHitSearcher extends Searcher {
    private static int id = 0;

    public AddHitSearcher(ComponentId id) {
        super(id);
    }

    public @Override Result search(Query query, Execution execution) {
        Result result = execution.search(query);

        Hit hit = new Hit(nextId());
	String hitTitle = "Produced by " + getId();
        hit.setField("title", hitTitle);

        result.hits().add(hit);
        return result;
    }

    private String nextId() {
	synchronized (getClass()) {
	    return Integer.toString(++id);
	}
    }
}
