// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.test;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.yolean.chain.After;
import com.yahoo.search.searchchain.Execution;

@After("*")
public class MockProvider extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
	String sourceName=query.properties().getString("sourceName","unknown");
	Result result=new Result(query);
	for (int i=1; i<=query.getHits(); i++) {
            Hit hit=new Hit(sourceName + ":" + i,1d/i);
	    hit.setSource(sourceName);
	    result.hits().add(hit);
	}
        return result;
    }

}

