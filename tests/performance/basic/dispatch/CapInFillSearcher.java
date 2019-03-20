package com.yahoo.example;

import com.yahoo.search.*;
import com.yahoo.search.result.*;
import com.yahoo.search.searchchain.*;
import com.yahoo.yolean.chain.After;

@After(PhaseNames.BLENDED_RESULT)
public class CapInFillSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        query.trace("running CapInFillSearcher", false, 1);
        Result result = execution.search(query);
        query.trace("before fill "+result.getHitCount()+" hits", false, 1);
        result.hits().trim(0, 3);
        execution.fill(result);
        query.trace("after fill: "+result.getHitCount()+" hits", false, 1);
        return result;
    }
}
