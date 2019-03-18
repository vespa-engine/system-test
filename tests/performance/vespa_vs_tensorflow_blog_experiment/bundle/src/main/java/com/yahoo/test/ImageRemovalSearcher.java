// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

import com.yahoo.component.chain.dependencies.Provides;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

/**
 * Remove this field before rendering, otherwise that will consume most of the time
 */
@Provides("ImageRemoval")
public class ImageRemovalSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
	Result result = execution.search(query);
        removeImagesFromSummary(result);
        return result;
    }

    private void removeImagesFromSummary(Result result) {
        for (Hit hit : result.hits().asList()) {
            hit.removeField("user_item_cf");
        }
    }

}




