// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example;

import com.yahoo.component.annotation.Inject;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.logging.LoggerEntry;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;

/**
 * A searcher that logs queries
 *
 * */
@Before("blendedResult")
public class LoggingSearcher extends Searcher {

	private final SpoolingLogger logger;

	@Inject
	public LoggingSearcher(SpoolingLogger logger) {
		this.logger = logger;
	}

	@Override
	public Result search(Query query, Execution execution) {
		Result result = execution.search(query); // Pass on to the next searcher to get results

		execution.fill(result);

		new LoggerEntry.Builder(logger)
				.query(query)
				.timestamp(execution.timer().first())
				.blob("foo").send();

		return result;
	}

	@Override
	public void deconstruct() {
		logger.deconstruct();
	}

}
