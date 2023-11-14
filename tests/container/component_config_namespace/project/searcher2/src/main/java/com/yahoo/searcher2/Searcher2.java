// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.searchers;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.xyzzy.FooConfig;
import com.yahoo.component.ComponentId;

public class Searcher2 extends Searcher {

    private final int number;

    public Searcher2(FooConfig config) {
        number = config.number();
    }

    protected Result addHit(String title, Result result) {
        Hit hit = new Hit("id");
        hit.setField("number", number);
        result.hits().add(hit);
        return result;
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.properties().set("query", query.properties().getString("query") + " AND demo");
        Result result = execution.search(query);
        return addHit(number + "", result);
    }
}
