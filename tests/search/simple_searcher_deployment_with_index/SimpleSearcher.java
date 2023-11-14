// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.example;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;

/**
 * A searcher adding a new hit.
 *
 * @author  Joe Developer
 */
@Before("blendedResult")
public class SimpleSearcher extends Searcher {

	@Override
	public Result search(Query query, Execution execution) {
		Result result = execution.search(query); // Pass on to the next searcher to get results
		Hit hit = new Hit("test");
		hit.setField("message", "Hello world");
		result.hits().add(hit);
		return result;
	}

}
