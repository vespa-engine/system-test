// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.prelude.fastsearch.FastHit;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.search.searchchain.PhaseNames;
import com.yahoo.yolean.chain.After;
import com.yahoo.yolean.chain.Before;

@After(PhaseNames.TRANSFORMED_QUERY)
@Before(PhaseNames.BLENDED_RESULT)
public class DispatchTestSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Result r = execution.search(query);
        execution.fill(r);
        for (Hit hit : r.hits().asList()) {
            if ( ! (hit instanceof FastHit)) continue;
            FastHit fhit = (FastHit) hit;
            hit.setField("distKey", fhit.getDistributionKey());
        }
        return r;
    }

}
