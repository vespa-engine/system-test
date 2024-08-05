// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;

/**
 * Fetch a custom HTTP header and insert it into the result HTTP headers.
 *
 * @author steinar
 */
public class HttpHeadersSearcher extends Searcher {
    private final String HEADER_NAME = "X-Vespa-System-Test";

    @Override
    public Result search(Query query, Execution execution) {
        String propagate = query.getHttpRequest().getHeader(HEADER_NAME);
        Result result = execution.search(query);
        if (propagate == null) {
            propagate = "No value for " + HEADER_NAME + " found.";
        }
        result.getHeaders(true).put(HEADER_NAME, propagate);
        return result;
    }
}
