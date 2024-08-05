// Copyright Vespa.ai. All rights reserved.
package com.yahoo.exporter;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.exporter.config.ExporterConfig;
import com.yahoo.component.ComponentId;

public class ExporterSearcher extends Searcher {

    private final String title;

    public ExporterSearcher(ExporterConfig config) {
        title = config.exampleString();
    }

    protected Result addHit(String title, Result result) {
        Hit hit = new Hit("id");
        hit.setField("title", title);
        result.hits().add(hit);
        return result;
    }

    @Override
    public Result search(Query query, Execution execution) {
        query.properties().set("query", query.properties().getString("query") + " AND demo");
        Result result = execution.search(query);
        return addHit(title, result);
    }
}
