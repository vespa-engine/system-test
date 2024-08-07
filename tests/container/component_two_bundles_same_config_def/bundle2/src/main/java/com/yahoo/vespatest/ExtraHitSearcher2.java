// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.ExtraHitConfig;
import com.yahoo.component.ComponentId;

public class ExtraHitSearcher2 extends Searcher {

    final String title;

    public ExtraHitSearcher2(ComponentId id, ExtraHitConfig config) {
        super(id);
        title = config.exampleString() + config.enumVal() + "!";
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
