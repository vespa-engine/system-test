// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

package com.yahoo.vespatest.attributeprefetch;

import java.util.Iterator;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

public class TestSearcher extends Searcher {

	public Result search(Query query, Execution execution) {
		query.properties().set("prefetch","true");
		Result result = execution.search(query);

		try {
			assertHitPhase1(result.hits().get(0),"stringfield");
			assertHitPhase1(result.hits().get(1),"fieldstring");
			assertHitPhase1(result.hits().get(2),"fieldstring");
			execution.fillAttributes(result);
			assertHitPhase2(result.hits().get(0),"stringfield");
			assertHitPhase2(result.hits().get(1),"fieldstring");
			assertHitPhase2(result.hits().get(2),"fieldstring");
			execution.fill(result);
			assertHitPhase3(result.hits().get(0),"stringfield");
			assertHitPhase3(result.hits().get(1),"fieldstring");
			assertHitPhase3(result.hits().get(2),"fieldstring");
			Hit feedback = new Hit("feedback");
			feedback.setField("feedback", "TEST SEARCHER: OK");
			result.hits().add(feedback);
		}
		catch (Exception e) {
			Hit feedback = new Hit("feedback");
			feedback.setField("feedback", "TEST SEARCHER: ERROR");
			feedback.setField("error", "ERROR DETAILS: " + e.getMessage());
			result.hits().add(feedback);
			makeThisTheFinalResult(result);
		}
		return result;
	}

	private void assertHitPhase1(Hit hit,String nameOfStringField) {
		if (hit.isCached()) return; // Nothing to check
		if (hit.getField(nameOfStringField)!= null)
			throw new RuntimeException("'stringfield' should not be set before "
									   + "filling in attributes in " + hit);

		if (hit.getField("body") != null)
			throw new RuntimeException("'body' should not be set before "
									   + "filling in docsums in " + hit);
	}

	private void assertHitPhase2(Hit hit,String nameOfStringField) {
		if (!hit.isCached()) {
			if (hit.getField("body") != null)
				throw new RuntimeException("'body' should not be set before "
										   + "filling in docsums in " + hit);
		}

		String stringFieldValue = (String) hit.getField(nameOfStringField);
		if (stringFieldValue == null) {
			throw new RuntimeException("'" + nameOfStringField + "' should be set after "
									   + "filling in attributes in " + hit);
		}
		else if (!stringFieldValue.equals("stringvalue")) {
			throw new RuntimeException("'stringfield' == " + stringFieldValue +
									   " != \"stringvalue\" in " + hit);
		}
	}

	private void assertHitPhase3(Hit hit,String nameOfStringField) {
		if (hit.getField("body")==null)
			throw new RuntimeException("'body' should be set after "
									   + "filling in docsums in " + hit);
		if (hit.getField(nameOfStringField)==null)
			throw new RuntimeException("'" + nameOfStringField + "' should be set after "
									   + "filling in docsums, since it is also a summary field in "
									   + hit);
	}

	private void makeThisTheFinalResult(Result result) {
		for (Hit hit : result.hits()) {
			hit.setFilled(result.getQuery().getPresentation().getSummary());
			hit.setFilled("attributeprefetch");
		}
	}

}
