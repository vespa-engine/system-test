// Copyright Vespa.ai. All rights reserved.
package com.yahoo.example;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

import java.util.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PostSearcher extends Searcher {

	@Override
    public Result search(Query query, Execution execution) {
		try {
			query.trace("running PostSearcher", false, 1);

			BufferedReader reader = new BufferedReader(new InputStreamReader(query.getHttpRequest().getData(), "UTF-8"));

			Result result = new Result(query);

			Hit h = new Hit("foo");
			h.setField("firstline", reader.readLine());
			result.hits().add(h);

			return result;
		} catch (Exception e) {
			return null;
		}
    }

}
