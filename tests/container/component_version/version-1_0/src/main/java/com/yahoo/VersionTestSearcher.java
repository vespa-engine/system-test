// Copyright Vespa.ai. All rights reserved.
package com.yahoo;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.component.ComponentId;

public class VersionTestSearcher extends Searcher {
    public VersionTestSearcher(ComponentId id) {
        super(id);
    }

    public @Override Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        Hit hit = new Hit("id");
        hit.setField("title", "Version 1.0.0 of VersionTestSearcher");
        result.hits().add(hit);
        return result;
    }
}
