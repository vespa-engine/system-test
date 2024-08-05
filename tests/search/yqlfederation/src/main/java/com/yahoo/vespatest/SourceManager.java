// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;

/**
 * If asked to search all sources indiscriminately, only ask the actual search
 * cluster.
 */
public class SourceManager extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        if (query.getModel().getSources().isEmpty()) {
            query.getModel().getSources().add("search");
        }
        return execution.search(query);
    }

}
