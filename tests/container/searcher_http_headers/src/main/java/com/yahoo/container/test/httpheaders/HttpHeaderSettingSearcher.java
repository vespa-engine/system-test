// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.container.test.httpheaders;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;

/**
 * Searcher that just sets a few headers.
 *
 * @author Jon Bratseth
 * @author Einar M R Rosenvinge
 */
public class HttpHeaderSettingSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        Result result = new Result(query);
        result.getHeaders(true).put("Cache-Control", "max-age=120");
        result.getHeaders(true).put("Cache-Control", "min-fresh=60");
        result.getHeaders(true).put("Expires", "120");
        return result;
    }
}

