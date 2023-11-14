// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.ExtraHitConfig;
import com.yahoo.component.ComponentId;

public class ExtraHitSearcher extends Searcher {

    final String title;

    public ExtraHitSearcher(ComponentId id, ExtraHitConfig config) {
        super(id);
        title = "New searcher says: " + config.exampleString();
    }

    public @Override Result search(Query query, Execution execution) {
        query.properties().set("query", query.properties().getString("query") + " AND demo");
        Result result = execution.search(query);
        Hit hit = new Hit("id");
        hit.setField("title", title);
        result.hits().add(hit);
        return result;
    }
}
