// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

public class ExtraHitSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        Hit hit = new Hit("id");
        hit.setField("colour", "red");
        result.hits().add(hit);
        result.setTotalHitCount(result.getTotalHitCount()+1);
        return result;
    }
}
