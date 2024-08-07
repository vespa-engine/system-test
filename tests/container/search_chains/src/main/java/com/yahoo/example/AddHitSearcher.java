// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.HitTitleConfig;
import com.yahoo.component.ComponentId;

public class AddHitSearcher extends Searcher {
    private final String hitTitle;
    private int id = 0;

    public AddHitSearcher(ComponentId id, HitTitleConfig config) {
        super(id);
	hitTitle = config.hitTitle();
    }

    public @Override Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        Hit hit = new Hit(nextId());
        hit.setField("title", hitTitle);
        result.hits().add(hit);
        return result;
    }

    private synchronized String nextId() {
	return Integer.toString(++id);
    }
}
