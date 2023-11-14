// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;


import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Provides;
import com.yahoo.search.Searcher;


@Provides("endSearcher")
public class EndSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Result r = new Result(query);
        Hit h = new Hit("EndSearcher", 1.0 / (double) 42);
        h.setField("theEnd", "EndSearcher: 42");
        r.hits().add(h);
        return r;
    }
}
