// Copyright Vespa.ai. All rights reserved.
package com.yahoo.testvespa;


import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Provides;
import com.yahoo.search.Searcher;


@Provides("thatThing")
public class ThatSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Result r = execution.search(query);
        int count = r.getConcreteHitCount();
        Hit h = new Hit("ThatSearcher", 1.0 / (double) count);
        h.setField("ThatSearcher",
                "ThatSearcher, current number of concrete hits: "
                + count);
        r.hits().add(h);
        return r;
    }
}
