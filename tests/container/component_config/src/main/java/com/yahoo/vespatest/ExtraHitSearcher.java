// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.vespatest.ExtraHitConfig;
import customer.ExtraHit2Config;
import com.yahoo.component.ComponentId;

public class ExtraHitSearcher extends Searcher {

    final String title;
    final String title2;

    public ExtraHitSearcher(ComponentId id, ExtraHitConfig config, ExtraHit2Config config2) {
        super(id);
        title = config.exampleString() + config.enumVal() + "!";
        title2 = config2.exampleString() + config2.enumVal() + "!";
    }

    public @Override Result search(Query query, Execution execution) {
        query.properties().set("query", query.properties().getString("query") + " AND demo");
        Result result = execution.search(query);
        Hit hit = new Hit("id");
        hit.setField("title", title);
        hit.setField("title2", title2);
        result.hits().add(hit);
        return result;
    }
}
