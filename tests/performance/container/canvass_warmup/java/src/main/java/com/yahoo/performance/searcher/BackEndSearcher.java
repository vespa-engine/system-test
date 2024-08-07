// Copyright Vespa.ai. All rights reserved.
package com.yahoo.performance.searcher;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.component.chain.dependencies.Provides;
import com.yahoo.component.chain.dependencies.After;

/**
 * @author bergum
 */
@Provides("GroupingOperator")
@After("com.yahoo.prelude.searcher.ValidateSortingSearcher")
public class BackEndSearcher extends com.yahoo.search.Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        Result empty = new Result(query);
        empty.setTotalHitCount(1);
        return empty;
    }

}

