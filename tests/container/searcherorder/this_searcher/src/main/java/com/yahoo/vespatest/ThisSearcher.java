// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;


import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Provides;
import com.yahoo.search.Searcher;


@Provides("thisThing")
public class ThisSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Result r = execution.search(query);
        int count = r.getConcreteHitCount();
        Hit h = new Hit("ThisSearcher", 1.0 / (double) count);
        h.setField("ThisSearcher",
                "ThisSearcher, current number of concrete hits: "
                + count);
        r.hits().add(h);
        return r;
    }
}
